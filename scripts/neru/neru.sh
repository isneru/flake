usage() {
  local prefix=${1:-} key
  printf '%s\n' "${!descs[@]}" | sort | while IFS= read -r key; do
    [ -z "$prefix" ] || [ "${key%% *}" = "$prefix" ] || continue
    printf '  neru %-20s %s\n' "$key" "${descs[$key]}"
  done
}

case "${1:-help}" in
help | -h | --help)
  echo "usage: neru <command> [args...]"
  usage
  exit 0
  ;;
--commands)
  for key in "${!descs[@]}"; do
    printf '%s\t%s\n' "$key" "${descs[$key]}"
  done
  exit 0
  ;;
esac

if [ $# -ge 2 ] && [ -n "${commands["$1 $2"]:-}" ]; then
  command=${commands["$1 $2"]}
  shift 2
elif [ -n "${commands["$1"]:-}" ]; then
  command=${commands["$1"]}
  shift
else
  listing=$(usage "$1")
  if [ -n "$listing" ]; then
    echo "usage: neru $1 <command> [args...]" >&2
    printf '%s\n' "$listing" >&2
  else
    echo "neru: unknown command '$1' (see neru help)" >&2
  fi
  exit 2
fi

exec "$command" "$@"
