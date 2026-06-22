#!/usr/bin/env bash
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"

case "${1:-full}" in
full) driftwm msg screenshot -o "$FILE" ;;
region) driftwm msg screenshot region --from-screen "$(slurp)" -o "$FILE" ;;
window) driftwm msg screenshot window -o "$FILE" ;;
esac

[ -f "$FILE" ] && wl-copy <"$FILE" && notify-send "Screenshot saved" "$FILE"
