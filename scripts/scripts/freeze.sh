freeze() {
  coproc FREEZE { exec wayfreeze --hide-cursor --after-freeze-cmd echo; }
  FREEZE_PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/wayfreeze.$$"
  printf '%s' "$FREEZE_PID" >"$FREEZE_PIDFILE"
  trap 'thaw; rm -f "$FREEZE_PIDFILE"' EXIT
  read -r -t 2 -u "${FREEZE[0]}" _ || true
}

thaw() {
  local pid
  [ -n "${FREEZE_PIDFILE:-}" ] || return 0
  pid=$(cat "$FREEZE_PIDFILE" 2>/dev/null) || return 0
  [ -n "$pid" ] || return 0
  : >"$FREEZE_PIDFILE"
  kill "$pid" 2>/dev/null || true
}
