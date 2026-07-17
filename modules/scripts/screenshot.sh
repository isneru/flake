#!/usr/bin/env bash
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"

capture() {
  case "${1:-full}" in
  full) grim - ;;
  region) grim -g "$(slurp)" - ;;
  window)
    geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    grim -g "$geom" -
    ;;
  esac
}

capture "${1:-full}" >"$FILE"
satty --filename "$FILE" -o "$FILE" \
  --no-window-decoration \
  --floating-hack \
  --copy-command wl-copy \
  --actions-on-enter save-to-clipboard,save-to-file,exit \
  --actions-on-escape exit
