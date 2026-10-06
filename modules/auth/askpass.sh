ask_dir="${XDG_RUNTIME_DIR:-/tmp}/quickshell/ask"

usage() {
  cat <<'EOF'
notch-askpass [prompt]
notch-askpass --forget

  Prompts for a secret in the notch and prints it on stdout, which is the
  contract SSH_ASKPASS, GIT_ASKPASS and SUDO_ASKPASS all share. Exits 1 when
  the prompt is denied or cancelled.

  --forget   drop every passphrase this helper stored in the login keyring
EOF
}

if [ "${1:-}" = "--forget" ]; then
  secret-tool clear service notch-askpass 2>/dev/null || true
  echo "notch-askpass: cleared" >&2
  exit 0
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

prompt="${1:-Password}"

kind=password
if [ "${SSH_ASKPASS_PROMPT:-}" = "confirm" ]; then
  kind=confirm
fi

source="${NOTCH_ASK_SOURCE:-}"
if [ -z "$source" ]; then
  case "$prompt" in
  *passphrase*) source=ssh ;;
  *"Username for"* | *"Password for"*) source=git ;;
  *"[sudo]"* | *"password for"*) source=sudo ;;
  *) source=ask ;;
  esac
fi

echo_input=false
case "$prompt" in
*"Username for"*) echo_input=true ;;
esac

case "$source" in
ssh)
  caption="SSH KEY PASSPHRASE"
  icon="key"
  footer="ssh - cancelling only fails this connection"
  ;;
git)
  caption="GIT CREDENTIALS"
  icon="cloud"
  footer="git - a token belongs here, not your account password"
  ;;
sudo)
  caption="SUDO PASSWORD"
  icon="terminal"
  footer="sudo - never remembered, by design"
  ;;
*)
  caption="AUTHENTICATION REQUIRED"
  icon="key"
  footer=""
  ;;
esac

if [ "$kind" = confirm ]; then
  caption="CONFIRM"
  icon="help"
  footer="ssh - answering no aborts the connection"
fi

remember=false
if [ "$kind" = password ] && [ "$source" != sudo ]; then
  remember=true
fi

asker="$(ps -o comm= -p "$PPID" 2>/dev/null | tr -d ' ')"
detail="${asker:-unknown} (pid $PPID)"

key="$(printf '%s\0%s' "$source" "$prompt" | sha256sum | cut -d' ' -f1)"
served="$ask_dir/served-$key"

served_recently() {
  [ -e "$served" ] || return 1
  local stamp
  stamp=$(stat -c %Y "$served" 2>/dev/null || echo 0)
  [ $(($(date +%s) - stamp)) -lt 120 ]
}

mkdir -p "$ask_dir"
chmod 700 "$ask_dir"

if [ "$remember" = true ]; then
  if served_recently; then
    rm -f "$served"
    secret-tool clear service notch-askpass key "$key" 2>/dev/null || true
  elif cached="$(secret-tool lookup service notch-askpass key "$key" 2>/dev/null)" && [ -n "$cached" ]; then
    : >"$served"
    printf '%s\n' "$cached"
    exit 0
  fi
fi

rm -f "$served"

id="$$-$(date +%s%N)"
fifo="$ask_dir/$id"
(
  umask 077
  mkfifo "$fifo"
)
trap 'rm -f "$fifo"' EXIT

tty_fallback() {
  [ -r /dev/tty ] || return 1
  if [ "$kind" = confirm ]; then
    printf '%s ' "$prompt" >/dev/tty
    read -r reply </dev/tty || return 1
    case "$reply" in
    y | Y | yes | Yes) printf 'yes\n' ;;
    *) return 1 ;;
    esac
    return 0
  fi
  printf '%s ' "$prompt" >/dev/tty
  stty -echo </dev/tty
  read -r reply </dev/tty || {
    stty echo </dev/tty
    return 1
  }
  stty echo </dev/tty
  printf '\n' >/dev/tty
  printf '%s\n' "$reply"
}

request="$(jq -nc \
  --arg id "$id" \
  --arg fifo "$fifo" \
  --arg source "$source" \
  --arg kind "$kind" \
  --arg caption "$caption" \
  --arg icon "$icon" \
  --arg message "$prompt" \
  --arg detail "$detail" \
  --arg prompt "$prompt" \
  --arg footer "$footer" \
  --argjson echo "$echo_input" \
  --argjson remember "$remember" \
  '$ARGS.named')"

if ! ipc="$(quickshell ipc call ask request "$request" 2>/dev/null)" || [ "$ipc" != queued ]; then
  if tty_fallback; then
    exit 0
  fi
  exit 1
fi

if ! response="$(timeout "${NOTCH_ASK_TIMEOUT:-120}" cat "$fifo")"; then
  exit 1
fi

status="${response%%$'\n'*}"
secret=""
case "$response" in
"$status"$'\n'*) secret="${response#*$'\n'}" ;;
esac

case "$status" in
ok) ;;
ok-remember)
  secret-tool store --label="Notch: $prompt" service notch-askpass key "$key" <<<"$secret" 2>/dev/null || true
  ;;
*) exit 1 ;;
esac

if [ "$kind" = confirm ]; then
  printf 'yes\n'
  exit 0
fi

printf '%s\n' "$secret"
