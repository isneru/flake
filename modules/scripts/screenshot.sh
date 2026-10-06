CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/screenshots"
LIBRARY="${XDG_PICTURES_DIR:-$HOME/pictures}/screenshots"
KEEP=20

notch() { quickshell ipc call notch "$@" >/dev/null 2>&1 || true; }

if [ "${1:-}" = "--save" ]; then
  mkdir -p "$LIBRARY"
  dest="$LIBRARY/${2##*/}"
  cp -- "$2" "$dest"
  notch shotSaved "$dest"
  exit 0
fi

MODE="${1:-full}"
EDIT=""
[ "${2:-}" = "--edit" ] && EDIT=1

geom=""
case "$MODE" in
region)
  freeze
  geom=$(slurp -w 2 -b '#00000066' -c '#FFFFFFFF' -s '#FFFFFF26') || exit 0
  sleep 0.2
  ;;
esac

mkdir -p "$CACHE"
FILE="$CACHE/screenshot-$(date +%Y%m%d-%H%M%S).png"

args=()
if [ -n "$geom" ]; then
  args=(-g "$geom")
fi
grim "${args[@]}" - | tee "$FILE" | wl-copy -t image/png
thaw

shopt -s nullglob
shots=("$CACHE"/screenshot-*.png)
if [ "${#shots[@]}" -gt "$KEEP" ]; then
  rm -f -- "${shots[@]:0:${#shots[@]}-KEEP}"
fi

if [ -n "$EDIT" ]; then
  satty --filename "$FILE" -o "$FILE" \
    --no-window-decoration \
    --floating-hack \
    --disable-notifications \
    --copy-command wl-copy \
    --actions-on-enter save-to-clipboard,save-to-file,exit \
    --actions-on-escape exit || true
fi

notch screenshot "$FILE"
