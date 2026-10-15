if hyprctl -j clients | grep -q '"class": "moodle",'; then
  hyprctl dispatch 'hl.dsp.focus({ window = "class:^(moodle)$" })'
else
  quickshell -c moodle -d
fi
