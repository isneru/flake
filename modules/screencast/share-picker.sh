share_dir="${XDG_RUNTIME_DIR:-/tmp}/quickshell/share"

if [ "${1:-}" = "--region" ]; then
  if ! sel="$(slurp -f '%o %x %y %w %h')"; then
    sel=cancel
  fi
  quickshell ipc call share region "$sel" >/dev/null 2>&1 || true
  exit 0
fi

allow_token=false
for arg in "$@"; do
  [ "$arg" = "--allow-token" ] && allow_token=true
done

windows="${XDPH_WINDOW_SHARING_LIST:-}"

id="$$-$(date +%s%N)"
fifo="$share_dir/$id"
mkdir -p "$share_dir"
chmod 700 "$share_dir"
(
  umask 077
  mkfifo "$fifo"
)
trap 'rm -f "$fifo"; quickshell ipc call share cancel "$id" >/dev/null 2>&1 || true' EXIT

request="$(jq -nc \
  --arg id "$id" \
  --arg fifo "$fifo" \
  --arg windows "$windows" \
  --argjson allowToken "$allow_token" \
  '$ARGS.named')"

if ! ipc="$(quickshell ipc call share request "$request" 2>/dev/null)" || [ "$ipc" != queued ]; then
  rm -f "$fifo"
  trap - EXIT
  exec hyprland-share-picker "$@"
fi

if ! response="$(timeout "${NOTCH_SHARE_TIMEOUT:-180}" cat "$fifo")"; then
  exit 1
fi

case "$response" in
cancel | "") exit 1 ;;
esac

printf '[SELECTION]%s\n' "$response"
