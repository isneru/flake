dir="${XDG_RUNTIME_DIR:-/tmp}"
stamp=$(date +%s%N)
types=$(wl-paste --list-types 2>/dev/null || true)

has() {
  printf '%s\n' "$types" | grep -qx "$1"
}

decode() {
  local s="${1//+/ }"
  printf '%b' "${s//%/\\x}"
}

if has text/uri-list; then
  uri=$(wl-paste --type text/uri-list | tr -d '\r' | grep -m1 '^file://' || true)
  path=$(decode "${uri#file://}")
  if [ -n "$uri" ] && [ -f "$path" ]; then
    echo "$path"
    exit 0
  fi
fi

raw=$(printf '%s\n' "$types" | grep -m1 -xE 'image/(gif|webp)' || true)
if [ -n "$raw" ]; then
  out="$dir/whatsapp-paste-$stamp.${raw#image/}"
  wl-paste --type "$raw" >"$out"
  echo "$out"
  exit 0
fi

if has text/html; then
  src=$(wl-paste --type text/html | grep -oiE '<img[^>]+src="[^"]+"' | head -1 | sed -E 's/.*src="([^"]+)"/\1/I; s/&amp;/\&/g' || true)
  case "$src" in
  http://* | https://*)
    out="$dir/whatsapp-paste-$stamp"
    type=$(curl -fsSL --max-time 20 -o "$out" -w '%{content_type}' "$src" || true)
    case "$type" in
    image/*)
      ext=${type#image/}
      ext=${ext%%;*}
      mv "$out" "$out.$ext"
      echo "$out.$ext"
      exit 0
      ;;
    esac
    rm -f "$out"
    ;;
  esac
fi

bitmap=$(printf '%s\n' "$types" | grep -m1 '^image/' || true)
if [ -n "$bitmap" ]; then
  out="$dir/whatsapp-paste-$stamp.${bitmap#image/}"
  wl-paste --type "$bitmap" >"$out"
  echo "$out"
fi
