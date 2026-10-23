if hyprctl -j clients | grep -q '"class": "excalidraw",'; then
  hyprctl dispatch 'hl.dsp.focus({ window = "class:^(excalidraw)$" })'
else
  quickshell -c excalidraw -d
fi
