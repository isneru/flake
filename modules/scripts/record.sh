#!/usr/bin/env bash
DIR="${XDG_VIDEOS_DIR:-$HOME/videos}"
mkdir -p "$DIR"

notch() { quickshell ipc call "$@" >/dev/null 2>&1 || true; }

if pgrep -x wf-recorder >/dev/null; then
  pkill -x wf-recorder
  notch recording stop
  notify-send -e "Recording stopped" -a "Recorder"
  exit 0
fi

audio="${1:-none}"

node_name() { wpctl inspect "$1" 2>/dev/null | sed -n 's/.*node\.name = "\(.*\)"/\1/p'; }

sink="$(node_name @DEFAULT_AUDIO_SINK@)"
mic="$(node_name @DEFAULT_AUDIO_SOURCE@)"

region="$(slurp -w 2 -b '#00000066' -c '#FFFFFFFF' -s '#FFFFFF26')" || exit 0
sleep 0.2
file="$DIR/recording-$(date +%Y%m%d-%H%M%S).mp4"

args=(--pixel-format yuv420p -F scale=out_range=full -g "$region" -f "$file")
case "$audio" in
system | both)
  if [[ -n $sink ]]; then
    args+=("-a${sink}.monitor")
  fi
  ;;
mic)
  if [[ -n $mic ]]; then
    args+=("-a${mic}")
  fi
  ;;
esac

notch recording start
wf-recorder "${args[@]}" >/dev/null 2>&1 &
disown

if [[ $audio == both && -n $mic ]]; then
  node=""
  for _ in $(seq 40); do
    node="$(pw-link -i 2>/dev/null | grep -o '^wf-recorder[0-9]*' | head -1 || true)"
    if [[ -n $node ]]; then
      break
    fi
    sleep 0.05
  done

  if [[ -n $node ]]; then
    if pw-link -o 2>/dev/null | grep -q "^${mic}:capture_MONO$"; then
      pw-link "${mic}:capture_MONO" "${node}:input_FL" || true
      pw-link "${mic}:capture_MONO" "${node}:input_FR" || true
    else
      pw-link "${mic}:capture_FL" "${node}:input_FL" || true
      pw-link "${mic}:capture_FR" "${node}:input_FR" || true
    fi
  fi
fi
