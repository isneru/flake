#!/usr/bin/env bash
color="$(hyprpicker --autocopy --format=hex)" || exit 0
notify-send -e "Color Picked" "$color" -a "Color Picker"
