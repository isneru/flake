: "${MUSIC_DIR:=$HOME/music}"
: "${PLAYLIST_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/mpd/playlists}"

state_dir="$MUSIC_DIR/.archive"
cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/sync-playlist/browser"

usage() {
  cat <<'EOF'
sync-playlist [--browser SPEC] <name> [url]
sync-playlist [--browser SPEC] --all

  <name>          folder under ~/music and the MPD playlist name
  [url]           remembered after the first run, so later syncs omit it
  --all           re-sync every playlist that has been synced before
  --browser SPEC  yt-dlp --cookies-from-browser spec; remembered

Cookies are read live from the browser on every run, so nothing goes stale.
EOF
}

detect_browsers() {
  local dir root label spec
  for dir in "$HOME"/.mozilla/firefox "$HOME"/.librewolf "$HOME"/.floorp "$HOME"/.waterfox; do
    [ -d "$dir" ] || continue
    for root in "$dir"/*/cookies.sqlite; do
      [ -e "$root" ] || continue
      label=$(basename "$dir" | sed 's/^\.//')
      printf '%s\tfirefox:%s\n' "$label" "$(dirname "$root")"
      break
    done
  done

  for root in "$HOME"/.config/*/Default/Cookies "$HOME"/.config/*/*/Default/Cookies; do
    [ -e "$root" ] || continue
    root=${root%/Default/Cookies}
    label=$(basename "$root")
    case "$root" in
    */google-chrome) spec=chrome ;;
    */chromium) spec=chromium ;;
    */BraveSoftware/Brave-Browser) spec=brave ;;
    */vivaldi) spec=vivaldi ;;
    */microsoft-edge*) spec=edge ;;
    */opera*) spec=opera ;;
    */naver-whale) spec=whale ;;
    *) spec="chromium:$root/Default" ;;
    esac
    printf '%s\t%s\n' "$label" "$spec"
  done

  root="${XDG_DATA_HOME:-$HOME/.local/share}/qutebrowser/webengine"
  if [ -e "$root/Cookies" ]; then
    printf '%s\t%s\n' "qutebrowser" "chromium:$root"
  fi
}

xdg_preferred() {
  local desktop id
  desktop=$(xdg-settings get default-web-browser 2>/dev/null) || return 1
  [ -n "$desktop" ] || return 1
  id=${desktop%.desktop}
  id=${id##*.}
  [ -n "$id" ] || return 1
  printf '%s\n' "$id" | tr '[:upper:]' '[:lower:]'
}

choose_browser() {
  local found preferred label spec count reply n
  found=$(detect_browsers)
  if [ -z "$found" ]; then
    echo "sync-playlist: no browser cookie store found." >&2
    echo "Pass one explicitly, e.g. --browser firefox" >&2
    return 1
  fi

  if preferred=$(xdg_preferred); then
    while IFS=$'\t' read -r label spec; do
      case "$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')" in
      *"$preferred"*)
        printf '%s\n' "$spec"
        return 0
        ;;
      esac
    done <<<"$found"
  fi

  count=$(printf '%s\n' "$found" | wc -l)
  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$found" | cut -f2
    return 0
  fi

  if [ ! -t 0 ]; then
    echo "sync-playlist: several browsers found and no terminal to ask on." >&2
    printf '%s\n' "$found" | cut -f1 | sed 's/^/  /' >&2
    echo "Pass one with --browser." >&2
    return 1
  fi

  echo "Which browser are you signed in to?" >&2
  n=0
  while IFS=$'\t' read -r label spec; do
    n=$((n + 1))
    printf '  %d) %s\n' "$n" "$label" >&2
  done <<<"$found"
  printf 'choice [1-%d]: ' "$count" >&2
  read -r reply </dev/tty
  case "$reply" in
  '' | *[!0-9]*)
    echo "sync-playlist: not a number." >&2
    return 1
    ;;
  esac
  if [ "$reply" -lt 1 ] || [ "$reply" -gt "$count" ]; then
    echo "sync-playlist: out of range." >&2
    return 1
  fi
  printf '%s\n' "$found" | sed -n "${reply}p" | cut -f2
}

resolve_browser() {
  local spec
  if [ -n "${browser_opt:-}" ]; then
    spec=$browser_opt
  elif [ -n "${SYNC_PLAYLIST_BROWSER:-}" ]; then
    printf '%s\n' "$SYNC_PLAYLIST_BROWSER"
    return 0
  elif [ -s "$cache_file" ]; then
    printf '%s\n' "$(cat "$cache_file")"
    return 0
  else
    spec=$(choose_browser) || return 1
  fi
  mkdir -p "$(dirname "$cache_file")"
  printf '%s\n' "$spec" >"$cache_file"
  printf '%s\n' "$spec"
}

sync_one() {
  local name=$1 url=${2:-} archive urlfile
  case "$name" in
  */* | .*)
    echo "sync-playlist: bad playlist name '$name'." >&2
    return 1
    ;;
  esac
  archive="$state_dir/$name.txt"
  urlfile="$state_dir/$name.url"

  if [ -z "$url" ]; then
    if [ -s "$urlfile" ]; then
      url=$(cat "$urlfile")
    else
      echo "sync-playlist: '$name' has no remembered url; pass one." >&2
      return 1
    fi
  fi

  mkdir -p "$state_dir" "$PLAYLIST_DIR" "$MUSIC_DIR/$name"
  printf '%s\n' "$url" >"$urlfile"

  echo ":: syncing '$name'" >&2
  yt-dlp \
    --cookies-from-browser "$browser" \
    --extractor-args "youtube:player_client=web_embedded,android_vr" \
    --download-archive "$archive" \
    --extract-audio --audio-quality 0 \
    --embed-metadata --embed-thumbnail \
    --convert-thumbnails png \
    --postprocessor-args "ThumbnailsConvertor+ffmpeg_o:-vf crop='min(iw,ih)':'min(iw,ih)'" \
    --ignore-errors --no-overwrites \
    --output "$MUSIC_DIR/$name/%(playlist_index)02d - %(title)s.%(ext)s" \
    "$url"

  (cd "$MUSIC_DIR" && find "$name" -type f ! -name '*.part' ! -name '*.ytdl' | sort) \
    >"$PLAYLIST_DIR/$name.m3u"
  echo ":: $name -> $(wc -l <"$PLAYLIST_DIR/$name.m3u") tracks" >&2
}

browser_opt=""
all=false
args=()
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --all)
    all=true
    shift
    ;;
  --browser)
    browser_opt=${2:-}
    shift 2
    ;;
  --browser=*)
    browser_opt=${1#--browser=}
    shift
    ;;
  --)
    shift
    args+=("$@")
    break
    ;;
  -*)
    echo "sync-playlist: unknown option $1" >&2
    usage >&2
    exit 1
    ;;
  *)
    args+=("$1")
    shift
    ;;
  esac
done

browser=$(resolve_browser)
echo ":: cookies from $browser" >&2

if [ "$all" = true ]; then
  shopt -s nullglob
  found=false
  for urlfile in "$state_dir"/*.url; do
    found=true
    name=$(basename "$urlfile" .url)
    sync_one "$name" || echo "sync-playlist: '$name' failed, continuing." >&2
  done
  [ "$found" = true ] || {
    echo "sync-playlist: nothing synced before." >&2
    exit 1
  }
  exit 0
fi

if [ "${#args[@]}" -lt 1 ]; then
  usage >&2
  exit 1
fi

sync_one "${args[0]}" "${args[1]:-}"
