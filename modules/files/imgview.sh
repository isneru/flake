#!/usr/bin/env bash

first=""
for f in "$@"; do
  if [ -f "$f" ]; then
    first="$f"
    break
  fi
done

args=()
if [ -n "$first" ]; then
  dims=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of "csv=p=0" "$first" 2>/dev/null || true)
  IFS=, read -r w h <<<"$dims"
  if [ "${w:-0}" -gt 0 ] && [ "${h:-0}" -gt 0 ]; then
    read -r mw mh < <(hyprctl monitors -j |
      jq -r 'first(.[] | select(.focused)) | "\(.width) \(.height)"')
    maxw=$((mw * 9 / 10))
    maxh=$((mh * 9 / 10))
    if [ "$w" -gt "$maxw" ]; then
      h=$((h * maxw / w))
      w=$maxw
    fi
    if [ "$h" -gt "$maxh" ]; then
      w=$((w * maxh / h))
      h=$maxh
    fi
    args=(--size="$w,$h")
  fi
fi

exec swayimg "${args[@]}" "$@"
