mode=${1:-notch}
state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"

mkdir -p "$state" "$conf"
printf '%s' "$mode" >"$state/mode"

if [ "$mode" = bare ]; then
  printf 'background_opacity 0.88\n' >"$conf/mode.conf"
else
  printf 'background_opacity 1.0\n' >"$conf/mode.conf"
fi

vesktop="${XDG_CONFIG_HOME:-$HOME/.config}/vesktop"
if [ -f "$vesktop/theme-modes/$mode.css" ]; then
  mkdir -p "$vesktop/themes"
  install -m 644 "$vesktop/theme-modes/$mode.css" "$vesktop/themes/mode.css"
fi

hyprctl reload >/dev/null

qute-reload >/dev/null 2>&1 || true

ya pub-to 0 notch-mode --str "$mode" >/dev/null 2>&1 || true

for sock in /tmp/kitty-*; do
  [ -S "$sock" ] || continue
  kitty @ --to "unix:$sock" load-config >/dev/null 2>&1 || true
done
