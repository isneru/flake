src=${1:?usage: phone-stickers <url-list|directory>}
cache="${XDG_CACHE_HOME:-$HOME/.cache}/phone-stickers"
key="${XDG_DATA_HOME:-$HOME/.local/share}/phone-launcher/key.jks"
frame="scale=512:512:force_original_aspect_ratio=decrease,format=rgba,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000"
tray="scale=96:96:force_original_aspect_ratio=decrease,format=rgba,pad=96:96:(ow-iw)/2:(oh-ih)/2:color=0x00000000"
threads=$(nproc)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$cache/media" "$cache/webp" "$work/assets"

say() { printf '\r\033[Kphone-stickers: %s\n' "$*" >&2; }

progress() { printf '\r\033[Kphone-stickers: %s %d/%d' "$1" "$2" "$3" >&2; }

throttle() {
  while (($(jobs -rp | wc -l) >= threads)); do
    wait -n || true
  done
}

fetch() {
  if curl -fsL "$1" -o "$2.part"; then
    mv "$2.part" "$2"
  else
    rm -f "$2.part"
    say "could not fetch $1"
  fi
}

fit() {
  local part="${2%.webp}.part.webp" fps quality
  for fps in 15 10; do
    for quality in 80 60 40 25 10; do
      if ! ffmpeg -v error -y -i "$1" -an -t 10 -vf "fps=$fps,$frame" -c:v libwebp_anim -loop 0 -quality "$quality" "$part"; then
        rm -f "$part"
        return 1
      fi
      if [ "$(stat -c %s "$part")" -le $((500 << 10)) ]; then
        mv "$part" "$2"
        return 0
      fi
    done
  done
  rm -f "$part"
  return 1
}

convert() {
  local frames
  frames=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$1" || true)
  if ! [[ $frames =~ ^[0-9]+$ ]] || ((frames < 2)); then
    say "skipping $1, it is not animated"
  elif ! fit "$1" "$2"; then
    say "skipping $1, it does not fit under 500 KB"
  fi
}

inputs=()
if [ -d "$src" ]; then
  for f in "$src"/*; do
    [ -f "$f" ] && inputs+=("$f")
  done
else
  mapfile -t urls < <(grep . "$src")
  for i in "${!urls[@]}"; do
    progress fetching $((i + 1)) ${#urls[@]}
    f="$cache/media/$(printf %s "${urls[i]}" | sha1sum | cut -c1-16)"
    if [ ! -s "$f" ]; then
      throttle
      fetch "${urls[i]}" "$f" &
    fi
  done
  wait
  for url in "${urls[@]}"; do
    f="$cache/media/$(printf %s "$url" | sha1sum | cut -c1-16)"
    [ -s "$f" ] && inputs+=("$f")
  done
fi

declare -A seen
candidates=()
outs=()
for f in "${inputs[@]}"; do
  out="$cache/webp/$(sha1sum <"$f" | cut -c1-16).webp"
  [ -z "${seen[$out]:-}" ] || continue
  seen[$out]=1
  candidates+=("$f")
  outs+=("$out")
done
for i in "${!outs[@]}"; do
  progress converting $((i + 1)) ${#outs[@]}
  if [ ! -s "${outs[i]}" ]; then
    throttle
    convert "${candidates[i]}" "${outs[i]}" &
  fi
done
wait
printf '\r\033[K' >&2

sources=()
stickers=()
for i in "${!outs[@]}"; do
  if [ -s "${outs[i]}" ]; then
    sources+=("${candidates[i]}")
    stickers+=("${outs[i]}")
  fi
done

count=${#stickers[@]}
if ((count < 3)); then
  say "a pack needs at least 3 animated stickers, found $count"
  exit 1
fi
packs=$(((count + 29) / 30))
per=$(((count + packs - 1) / packs))

json=
for ((p = 0; p < packs; p++)); do
  id="discord$((p + 1))"
  mkdir "$work/assets/$id"
  files=
  for ((i = p * per; i < count && i < (p + 1) * per; i++)); do
    cp "${stickers[i]}" "$work/assets/$id/$i.webp"
    files+="${files:+,}\"$i.webp\""
  done
  ffmpeg -v error -i "${sources[p * per]}" -frames:v 1 -vf "$tray" "$work/assets/$id/tray.png"
  json+="${json:+,}{\"id\":\"$id\",\"name\":\"Discord $((p + 1))\",\"stickers\":[$files]}"
done
version=$(cat "${stickers[@]}" | sha1sum | cut -c1-16)
printf '{"version":"%s","packs":[%s]}\n' "$version" "$json" >"$work/assets/contents.json"

"$tools/aapt2" link -o "$work/base.apk" -I "$platform/android.jar" --manifest "$manifest" \
  -A "$work/assets" --no-compress --min-sdk-version 34 --target-sdk-version 36 \
  --version-code "$(date +%s)" --version-name "$version"
cp "$dex" "$work/classes.dex"
chmod u+w "$work/classes.dex"
zip -q -X -j "$work/base.apk" "$work/classes.dex"
"$tools/zipalign" -f 4 "$work/base.apk" "$work/aligned.apk"

if [ ! -f "$key" ]; then
  mkdir -p "${key%/*}"
  keytool -genkeypair -keystore "$key" -storepass android -alias bare \
    -keyalg RSA -keysize 2048 -validity 36500 -dname CN=bare
fi
apksigner sign --ks "$key" --ks-pass pass:android --out "$work/stickers.apk" "$work/aligned.apk"

say "$count stickers in $packs pack(s)"
if [ "$(adb get-state 2>/dev/null)" = device ]; then
  adb install -r "$work/stickers.apk"
elif what=apk file=$work/stickers.apk && online && send phone -o ConnectTimeout=20 -o ProxyCommand="tailscale nc %h %p"; then
  say "sent over the tailnet, install it on the phone"
else
  say "no adb device, and the phone is not reachable on the tailnet"
  exit 1
fi
say "open Stickers on the phone and tap each pack"
