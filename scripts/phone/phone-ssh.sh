online() {
  tailscale status --json 2>/dev/null |
    python3 -c 'import json, sys; sys.exit(not any(p["DNSName"].split(".")[0] == "phone" and p["Online"] for p in (json.load(sys.stdin).get("Peer") or {}).values()))'
}

send() {
  host=$1
  shift
  reply=$(ssh -T "$@" -p 8022 -i "$HOME/.ssh/phone_ed25519" \
    -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=3 \
    -o HostKeyAlias=phone -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$known_hosts" -o GlobalKnownHostsFile=/dev/null \
    "$host" "$what" <"$file") && { [ "$what" = wallpaper ] || [ "$reply" = ok ]; }
}
