out="${XDG_RUNTIME_DIR:-/tmp}/quickshell-qr"
: >"$out"

freeze

if ! region=$(slurp -d -w 2 -b '#00000066' -c '#FFFFFFFF' -s '#FFFFFF26'); then
  printf 'CANCEL' >"$out"
  exit 0
fi

sleep 0.2

if text=$({
  grim -g "$region" -
  thaw
} | zbarimg --raw -q PNG:-); then
  printf '%s' "$text" | wl-copy
  printf 'OK %s' "$text" >"$out"
else
  printf 'NONE' >"$out"
fi
