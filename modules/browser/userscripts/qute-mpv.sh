url="${QUTE_URL:-}"

if [ -z "$url" ]; then
  exit 1
fi

{
  echo "jseval -q -w main document.querySelectorAll('video').forEach(function (v) { v.pause(); })"
  echo "message-info 'Opening in mpv'"
} >>"$QUTE_FIFO"

# shellcheck disable=SC2016
setsid --fork sh -c \
  '{ mpv --force-window --quiet --keep-open=yes --ytdl -- "$1"; echo "exited with status $?"; } 2>&1 | systemd-cat -t mpv' \
  sh "$url"
