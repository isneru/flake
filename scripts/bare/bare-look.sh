look=${1:-flat}
[ "$look" = soft ] || look=flat
state="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"

mkdir -p "$state" "$conf"
printf '%s' "$look" >"$state/look"

if [ "$look" = flat ]; then
  printf 'background_opacity 0.80\n' >"$conf/look.conf"
else
  printf 'background_opacity 1.0\n' >"$conf/look.conf"
fi

vesktop="${XDG_CONFIG_HOME:-$HOME/.config}/vesktop"
if [ -f "$vesktop/theme-looks/$look.css" ]; then
  mkdir -p "$vesktop/themes"
  install -m 644 "$vesktop/theme-looks/$look.css" "$vesktop/themes/look.css"
fi

hyprctl reload >/dev/null

neru qute reload >/dev/null 2>&1 || true

neru zathura reload >/dev/null 2>&1 || true

for sock in /tmp/kitty-*; do
  [ -S "$sock" ] || continue
  kitty @ --to "unix:$sock" load-config >/dev/null 2>&1 || true
done
