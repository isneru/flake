if hyprctl -j clients | grep -q '"class": "whatsapp",'; then
  hyprctl dispatch 'hl.dsp.focus({ window = "class:^(whatsapp)$" })'
else
  quickshell -c whatsapp -d
fi
