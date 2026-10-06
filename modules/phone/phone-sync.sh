state="${XDG_STATE_HOME:-$HOME/.local/state}"
current="$state/quickshell/wallpaper"
pushed="$state/phone-sync/pushed"
mkdir -p "${pushed%/*}"
crop=$(mktemp)
trap 'rm -f "$crop"' EXIT

push() {
  ssh -T -p 8022 -i "$HOME/.ssh/phone_ed25519" \
    -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=3 \
    -o HostKeyAlias=phone -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$known_hosts" -o GlobalKnownHostsFile=/dev/null \
    "$1" <"$crop"
}

while :; do
  [ -s "$current" ] || exit 0
  wall=$(<"$current")
  [ -f "$wall" ] || exit 0
  stamp=$(cksum <"$wall")
  last=$(cat "$pushed" 2>/dev/null || true)
  [ "$stamp" != "$last" ] || exit 0
  python3 -c 'import sys; from PIL import Image, ImageOps; ImageOps.fit(Image.open(sys.argv[1]).convert("RGB"), (1440, 3120)).save(sys.argv[2], "JPEG", quality=92)' "$wall" "$crop"
  sent=
  for host in $(ip -4 route show default | awk '$2 == "via" { print $3 }'); do
    if push "$host"; then
      sent=1
      break
    fi
  done
  if [ -z "$sent" ]; then
    echo "phone-sync: phone not reachable" >&2
    exit 0
  fi
  printf '%s\n' "$stamp" >"$pushed"
done
