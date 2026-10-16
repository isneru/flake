inotifywait -m -r -q -e close_write,moved_to,moved_from,delete --format '%w%f' "$HOME/notes/isep" |
  while read -r path; do
    case "$path" in
    */deadlines/*.md) ;;
    *) continue ;;
    esac
    while read -r -t 2 _; do :; done
    gcal push && gcal sync || true
  done
