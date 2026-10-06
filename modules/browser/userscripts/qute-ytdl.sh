#!/usr/bin/env bash

url="${QUTE_URL:?no URL in the environment}"
dest="${XDG_VIDEOS_DIR:-$HOME/videos}/qutebrowser"
mkdir -p "$dest"

if [[ -n ${QUTE_FIFO:-} ]]; then
  printf "message-info 'yt-dlp: downloading to %s'\n" "$dest" >>"$QUTE_FIFO"
fi

# shellcheck disable=SC2016
setsid -f bash -c '
  dest=$1 url=$2
  if file=$(yt-dlp --no-playlist --paths "$dest" --output "%(title)s.%(ext)s" \
      --no-simulate --print after-move:filepath "$url" 2>/dev/null | tail -1); then
    notify-send -e -a qutebrowser "Download finished" "${file:-$url}"
  else
    notify-send -e -a qutebrowser -u critical "Download failed" "$url"
  fi
' _ "$dest" "$url"
