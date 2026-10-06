conf="${XDG_CONFIG_HOME:-$HOME/.config}/wmenu/colors.env"
WMENU_ARGS=()
if [ -r "$conf" ]; then
  # shellcheck source=/dev/null
  . "$conf"
fi
exec wmenu -i -l "${NOTCH_MENU_LINES:-12}" "${WMENU_ARGS[@]}" "$@"
