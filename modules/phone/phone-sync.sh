state="${XDG_STATE_HOME:-$HOME/.local/state}"
rendered="${XDG_DATA_HOME:-$HOME/.local/share}/theme-engine"
pushed="$state/phone-sync/pushed"
mkdir -p "${pushed%/*}"
crop=$(mktemp)
trap 'rm -f "$crop"' EXIT

push() {
  what=$1 file=$2
  for host in $(ip -4 route show default | awk '$2 == "via" { print $3 }'); do
    send "$host" && return
  done
  if online && send phone -o ConnectTimeout=20 -o ProxyCommand="tailscale nc %h %p"; then
    return
  fi
  echo "phone-sync: $1 not pushed" >&2
  exit 0
}

sync() {
  [ -f "$3" ] || return 0
  stamp=$(cksum <"$3")
  [ "$stamp" != "$(cat "$pushed$2" 2>/dev/null || true)" ] || return 0
  if [ "$1" = wallpaper ]; then
    python3 -c 'import sys; from PIL import Image, ImageOps; ImageOps.fit(Image.open(sys.argv[1]).convert("RGB"), (1440, 3120)).save(sys.argv[2], "JPEG", quality=92)' "$3" "$crop"
    push "$1" "$crop"
  else
    push "$1" "$3"
  fi
  printf '%s\n' "$stamp" >"$pushed$2"
  changed=1
}

while :; do
  changed=
  sync wallpaper "" "$(cat "$state/quickshell/wallpaper" 2>/dev/null || true)"
  sync termux -termux "$rendered/phone-termux.properties"
  family=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["font"])' "$rendered/phone.json" 2>/dev/null || true)
  sync font -font "$(fc-match -f '%{file}' "$family:style=Regular" 2>/dev/null || true)"
  sync theme -theme "$rendered/phone.json"
  [ -n "$changed" ] || exit 0
done
