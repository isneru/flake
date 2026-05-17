#!/usr/bin/env bash
choice=$(printf "󰒲  suspend\n󰜉  reboot\n󰐥  shutdown\n󰍃  logout\n󰌾  lock" | tofi --prompt-text "power menu: ")
case "$choice" in
  *suspend*)  systemctl suspend ;;
  *reboot*)   systemctl reboot ;;
  *shutdown*) systemctl poweroff ;;
  *logout*)   niri msg action quit ;;
  *lock*)     hyprlock ;;
esac
