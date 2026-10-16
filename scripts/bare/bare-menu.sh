conf="${XDG_CONFIG_HOME:-$HOME/.config}/wmenu/colors.env"
look="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/look"
export WMENU_ALPHA=bf
[ "$(cat "$look" 2>/dev/null)" = soft ] && WMENU_ALPHA=ff
WMENU_ARGS=()
if [ -r "$conf" ]; then
  # shellcheck source=/dev/null
  . "$conf"
fi
exec wmenu -i -l "${BARE_MENU_LINES:-12}" "${WMENU_ARGS[@]}" "$@"
