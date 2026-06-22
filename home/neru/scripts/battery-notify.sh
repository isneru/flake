#!/usr/bin/env bash
LOW_PERCENT=15
CRITICAL_PERCENT=12
POLL_INTERVAL=60
STATE_DIR="/tmp/driftwm-battery-notify"

mkdir -p "$STATE_DIR"

check_cooldown() {
  local key="$1" cooldown="$2"
  local now state_file last
  now=$(date +%s)
  state_file="$STATE_DIR/$key"
  if [ -f "$state_file" ]; then
    last=$(cat "$state_file")
    [ $((now - last)) -lt "$cooldown" ] && return 1
  fi
  echo "$now" >"$state_file"
  return 0
}

trap 'rm -rf "$STATE_DIR"; exit 0' EXIT INT TERM

while true; do
  for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    status=$(cat "$bat/status" 2>/dev/null)
    [ "$status" = "Discharging" ] || continue
    pct=$(cat "$bat/capacity" 2>/dev/null)
    [ -z "$pct" ] && continue

    if [ "$pct" -le "$CRITICAL_PERCENT" ]; then
      check_cooldown critical 180 &&
        notify-send -u critical \
          --app-name="Battery" \
          --icon=battery-empty-symbolic \
          "Critical battery" \
          "${pct}% remaining -- plug in now"
    elif [ "$pct" -le "$LOW_PERCENT" ]; then
      check_cooldown low 600 &&
        notify-send -u normal \
          --app-name="Battery" \
          --icon=battery-caution-symbolic \
          "Low battery" \
          "${pct}% remaining -- consider charging"
    fi
  done
  sleep "$POLL_INTERVAL"
done
