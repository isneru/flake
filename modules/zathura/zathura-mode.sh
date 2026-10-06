state="${XDG_STATE_HOME:-$HOME/.local/state}/zathura/mode"
modes="${XDG_CONFIG_HOME:-$HOME/.config}/zathura/modes"

current=$(basename "$(readlink "$state" || echo theme)")

case "${1:-next}" in
next)
  case "$current" in
  light) mode=dark ;;
  dark) mode=theme ;;
  *) mode=light ;;
  esac
  ;;
light | dark | theme) mode=$1 ;;
reload) mode="" ;;
*)
  echo "usage: zathura-mode [next|light|dark|theme|reload]" >&2
  exit 2
  ;;
esac

if [ -n "$mode" ]; then
  mkdir -p "$(dirname "$state")"
  ln -sfn "$modes/$mode" "$state"
fi

busctl --user --no-legend --acquired list | while read -r name _; do
  case "$name" in
  org.pwmt.zathura.PID-*)
    busctl --user call "$name" /org/pwmt/zathura org.pwmt.zathura SourceConfig >/dev/null || true
    ;;
  esac
done
