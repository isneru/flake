echo -e "  󰒲  (s)uspend\n  󰜉  (r)eboot\n  󰐥  (p)oweroff\n  󰍃  (l)ogout\n  󰷛  (x)lock"
read -n 1 -p "  > " choice
case $choice in
  s) systemctl suspend ;;
  r) systemctl reboot ;;
  p) systemctl poweroff ;;
  l) niri msg action quit ;;
  x) niri msg action lock-screen ;;
  *) exit 0 ;;
esac
