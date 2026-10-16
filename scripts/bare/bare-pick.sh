ipc() { quickshell ipc call menu "$@" 2>/dev/null; }

descendants() {
  local c kids
  kids=$(cat /proc/"$1"/task/*/children 2>/dev/null) || true
  for c in $kids; do
    echo "$c"
    descendants "$c"
  done
}

claim() {
  local pidfile="${XDG_RUNTIME_DIR:-/tmp}/bare-pick.pid" old kids
  exec 9>"$pidfile.lock"
  flock 9
  old=$(cat "$pidfile" 2>/dev/null || true)
  if [ -n "$old" ] && [ "$old" != $$ ] && grep -qa bare-pick /proc/"$old"/cmdline 2>/dev/null; then
    kids=$(descendants "$old")
    # shellcheck disable=SC2086
    kill "$old" $kids 2>/dev/null || true
  fi
  echo $$ >"$pidfile"
  flock -u 9
  exec 9>&-
}

LIST=20
EXTRA="${XDG_CONFIG_HOME:-$HOME/.config}/bare/pick"

menu() {
  local prompt=$1 lines=$2
  shift 2
  if [ "$lines" -gt 0 ]; then
    bare-menu -c -p "$prompt: " -l "$lines" "$@"
  else
    bare-menu -p "$prompt: " -l 0 "$@"
  fi
}

choose() {
  local rows=$1 prompt=$2 lines=$3 sel
  [ -n "$rows" ] || return 1
  sel=$(printf '%s\n' "$rows" | cut -f2- | menu "$prompt" "$lines") || return 1
  [ -n "$sel" ] || return 1
  printf '%s\n' "$rows" | awk -F'\t' -v s="$sel" 'substr($0, index($0, "\t") + 1) == s { print $1; exit }'
}

extras() {
  local f
  for f in "$EXTRA"/*.sh; do
    [ -f "$f" ] || continue
    f=${f##*/}
    printf '%s\n' "${f%.sh}"
  done
}

act() {
  local verb=$1 src=$2 prompt=$3 lines=$4 key
  key=$(choose "$(ipc "$src")" "$prompt" "$lines") || return 0
  [ -n "$key" ] && ipc "$verb" "$key" >/dev/null
}

tray_rows() {
  local rows
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    rows=$(ipc trayRows)
    [ -n "$rows" ] && {
      printf '%s\n' "$rows"
      return 0
    }
    sleep 0.1
  done
  return 1
}

window_rows() {
  hyprctl clients -j | jq -r '
    map(select(.workspace.id > 0))
    | sort_by(.focusHistoryID == 0, .focusHistoryID < 0, .focusHistoryID)[]
    | (.class | split(".") | last // "?") as $c
    | (if $c == "qutebrowser" then [$c, (.title | sub(" - qutebrowser$"; ""))]
      else [$c, .title] end) as [$cls, $title]
    | "\(.address)\t[\(.workspace.name):\($cls)] \"\($title)\""'
}

tray_menu() {
  local id=$1 rows sel
  [ "$(ipc trayOpen "$id")" = menu ] || return 0
  while rows=$(tray_rows); do
    sel=$(choose "$rows" menu "$LIST") || break
    case $sel in
    activate)
      ipc trayActivate "$id" >/dev/null
      break
      ;;
    sub:*) ipc traySub "${sel#sub:}" >/dev/null ;;
    *)
      ipc trayTrigger "$sel" >/dev/null
      return 0
      ;;
    esac
  done
  ipc trayClose >/dev/null
}

browse() {
  local dir=$1 sel label
  while :; do
    label=${dir/#$HOME/\~}
    sel=$({
      printf '../\n'
      find -L "$dir" -mindepth 1 -maxdepth 1 -not -name '.*' -type d -printf '%f/\n' 2>/dev/null | sort || true
      find -L "$dir" -mindepth 1 -maxdepth 1 -not -name '.*' -type f -printf '%f\n' 2>/dev/null | sort || true
    } | menu "$label" "$LIST" -I "$dir") || return 1
    case $sel in
    ../) dir=$(dirname "$dir") ;;
    */) [ -d "${dir%/}/${sel%/}" ] && dir=${dir%/}/${sel%/} ;;
    *)
      [ -f "${dir%/}/$sel" ] || continue
      printf '%s\n' "${dir%/}/$sel"
      return 0
      ;;
    esac
  done
}

send_peer() {
  local rows fp
  rows=$(ipc sendPeers)
  while :; do
    fp=$(choose "$(printf '%s%srescan\trescan\n' "$rows" "${rows:+$'\n'}")" device "$LIST") || return 1
    if [ "$fp" != rescan ]; then
      ipc sendTo "$fp" >/dev/null
      return 0
    fi
    ipc sendScan >/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
      sleep 0.25
      rows=$(ipc sendPeers)
      [ -n "$rows" ] && break
    done
  done
}

send_wait() {
  local before=$1
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(ipc sendState)" != "$before" ] && return 0
    sleep 0.1
  done
}

send() {
  local state rows prompt sel text path
  while :; do
    state=$(ipc sendState)
    case $state in
    down)
      notify-send LocalSend "the daemon is not running"
      return 0
      ;;
    "") prompt=send ;;
    *) prompt="send [$state]" ;;
    esac
    rows=""
    [ -n "$state" ] && rows+=$'to\tsend to a device\n'
    rows+=$'file\tadd a file\nclipboard\tadd the clipboard\nshelf\tadd the shelf\ntext\twrite a message\n'
    [ -n "$state" ] && rows+=$'clear\tclear everything\n'
    sel=$(choose "${rows%$'\n'}" "$prompt" "$LIST") || return 0
    case $sel in
    to)
      send_peer && return 0
      ;;
    file)
      path=$(browse "$HOME") && ipc sendStage "$path" >/dev/null
      ;;
    clipboard)
      ipc sendPaste >/dev/null
      send_wait "$state"
      ;;
    shelf) ipc sendShelf >/dev/null ;;
    text)
      text=$(printf '' | menu message 0) || continue
      [ -n "$text" ] && ipc sendCompose "$text" >/dev/null
      ;;
    clear) ipc sendClear >/dev/null ;;
    esac
  done
}

calc_eval() {
  {
    printf '%s\n' "${vars[@]}"
    [ -n "$last" ] && printf 'ans := %s\n' "$last"
    printf '%s\n' "$1"
  } | qalc -t -f - 2>/dev/null | tr '\n' ' ' | sed 's/ *$//'
}

calc() {
  local typed expr name result last="" log="" lines
  local -a vars=()
  while :; do
    lines=$(printf '%s' "$log" | grep -c '' || true)
    [ "$lines" -gt 10 ] && lines=10
    typed=$(printf '%s' "$log" | menu calc "$LIST" -R) || return 0
    if [ -z "$typed" ]; then
      [ -n "$last" ] && printf '%s' "$last" | wl-copy
      return 0
    fi
    expr=$(printf '%s' "$typed" | sed -E 's/\b_\b/ans/g')
    name=""
    if [[ $expr =~ ^[[:space:]]*([A-Za-z][A-Za-z0-9_]*)[[:space:]]*:?=[[:space:]]*([^=].*)$ ]]; then
      name=${BASH_REMATCH[1]}
      expr=${BASH_REMATCH[2]}
    fi
    result=$(calc_eval "$expr")
    if [ -z "$result" ]; then
      log=$(printf '%s = ?\n%s' "$typed" "$log")
      continue
    fi
    last=$result
    if [ -n "$name" ]; then
      vars+=("$name := $result")
      log=$(printf '%s = %s\n%s' "$name" "$result" "$log")
    else
      log=$(printf '%s = %s\n%s' "$typed" "$result" "$log")
    fi
  done
}

qs() { quickshell ipc call "$@" 2>/dev/null; }

dur() {
  local s=${1// /}
  if [[ $s =~ ^[0-9]+$ ]]; then
    echo $((10#$s * 60))
  elif [[ $s =~ ^([0-9]+)h([0-9]+)$ ]]; then
    echo $((10#${BASH_REMATCH[1]} * 3600 + 10#${BASH_REMATCH[2]} * 60))
  elif [ -n "$s" ] && [[ $s =~ ^(([0-9]+)h)?(([0-9]+)(m|min))?(([0-9]+)s)?$ ]]; then
    echo $((10#${BASH_REMATCH[2]:-0} * 3600 + 10#${BASH_REMATCH[4]:-0} * 60 + 10#${BASH_REMATCH[7]:-0}))
  else
    return 1
  fi
}

timer() {
  local status sel secs toggle
  status=$(qs timer status) || status=""
  if [ -z "$status" ] || [ "$status" = idle ]; then
    sel=$(printf 'pomodoro\n1m\n5m\n10m\n15m\n25m\n45m\n' | menu "timer (12m, 1h30, 90s)" "$LIST") || return 0
    case $sel in
    pomodoro) qs timer focus >/dev/null ;;
    *) secs=$(dur "$sel") && qs timer start "$secs" >/dev/null ;;
    esac
    return 0
  fi
  case $status in
  *paused*) toggle=resume ;;
  *) toggle=pause ;;
  esac
  sel=$(printf '%s\n' "$toggle" +1m +5m stop | menu "timer [$status]" "$LIST") || return 0
  case $sel in
  pause | resume) qs timer toggle >/dev/null ;;
  stop) qs timer stop >/dev/null ;;
  +*) secs=$(dur "${sel#+}") && qs timer extend "$secs" >/dev/null ;;
  *) secs=$(dur "$sel") && qs timer start "$secs" >/dev/null ;;
  esac
}

shelf_item() {
  local path=$1
  case $(printf 'open\nreveal\ncopy the file\ncopy the path\nsend\nremove\n' | menu "\"${path##*/}\"" "$LIST") in
  open) qs shelf open "$path" ;;
  reveal) qs shelf reveal "$path" ;;
  "copy the file") qs shelf copy "$path" ;;
  "copy the path") qs shelf copyPath "$path" ;;
  send)
    ipc sendStage "$path" >/dev/null
    send
    ;;
  remove)
    qs shelf remove "$path"
    return 1
    ;;
  *) return 1 ;;
  esac
}

shelf() {
  local rows extra lines key path
  while :; do
    rows=$(qs shelf rows) || rows=""
    extra=$'add\tadd a file'
    [ -n "$rows" ] && extra+=$'\nclear\tclear the shelf'
    rows=${rows:+$rows$'\n'}$extra
    lines=$(printf '%s\n' "$rows" | wc -l)
    [ "$lines" -gt 10 ] && lines=10
    key=$(choose "$rows" shelf "$LIST") || return 0
    case $key in
    add) path=$(browse "$HOME") && qs shelf add "$path" >/dev/null ;;
    clear) qs shelf clear ;;
    *) shelf_item "$key" && return 0 ;;
    esac
  done
}

label_of() { printf '%s\n' "$1" | awk -F'\t' -v k="$2" '$1 == k { print substr($0, index($0, "\t") + 1); exit }'; }

night_temp() {
  local sel
  sel=$(printf '%s K\n' 2500 3000 3500 4000 4500 5000 5500 6000 | menu "night light [$(ipc nightTemp 0)]" "$LIST") || return 0
  sel=${sel%%K*}
  sel=${sel//[!0-9]/}
  [ -n "$sel" ] && ipc nightTemp "$sel" >/dev/null
}

caffeinate_row() {
  local mark='[ ]'
  systemctl --user is-active --quiet caffeinate && mark='[x]'
  printf 'caffeinate\t%s caffeinate (stay awake with the lid shut)' "$mark"
}

control_menu() {
  local key vpn
  while :; do
    vpn=$(vpn_rows)
    key=$(choose "$(ipc control | R="$(caffeinate_row)${vpn:+$'\n'$vpn}" awk '/^nightTemp\t/ { print ENVIRON["R"] } { print }')" "control [$(ipc controlState)]" "$LIST") || return 0
    case $key in
    networks) exec "$0" wifi ;;
    devices) exec "$0" bt ;;
    audio) exec "$0" audio ;;
    nightTemp) night_temp ;;
    vpn:*)
      if systemctl is-active --quiet "${key#vpn:}"; then
        BARE_ASK_SOURCE=sudo sudo -A systemctl stop "${key#vpn:}"
      else
        BARE_ASK_SOURCE=sudo sudo -A systemctl start "${key#vpn:}"
      fi
      ;;
    caffeinate)
      if systemctl --user is-active --quiet caffeinate; then
        systemctl --user stop caffeinate
      else
        systemd-run --user --quiet --collect --unit=caffeinate \
          systemd-inhibit --what=handle-lid-switch --who=caffeinate --why="caffeinate is on" --mode=block sleep infinity
      fi
      ;;
    *)
      ipc controlToggle "$key" >/dev/null
      sleep 0.3
      ;;
    esac
  done
}

bt_menu() {
  local rows key acts act
  while :; do
    rows=$(ipc bt)
    if [ -z "$rows" ]; then
      notify-send Bluetooth "no adapter found"
      return 0
    fi
    key=$(choose "$rows" bluetooth "$LIST") || break
    case $key in
    power)
      ipc btPower >/dev/null
      sleep 1
      ;;
    scan) [ "$(ipc btScan)" = scanning ] && sleep 4 ;;
    visible) ipc btVisible >/dev/null ;;
    *)
      acts=$(ipc btActions "$key")
      [ -n "$acts" ] || continue
      act=$(choose "$acts" "$(label_of "$rows" "$key" | sed 's/^\[[ x]\] //')" "$LIST") || continue
      ipc btAct "$key" "$act" >/dev/null
      sleep 1
      ;;
    esac
  done
  ipc btStopScan >/dev/null
}

audio_level() {
  local sel mark='[ ]'
  [[ $2 == *" muted" ]] && mark='[x]'
  sel=$(printf '%s\n' "$mark muted" 100% 75% 50% 25% | menu "$2" "$LIST") || return 0
  case $sel in
  "[x] muted" | "[ ] muted") ipc audioMute "$1" >/dev/null ;;
  *)
    sel=${sel//[!0-9]/}
    [ -n "$sel" ] && ipc audioLevel "$1" "$sel" >/dev/null
    ;;
  esac
}

audio_menu() {
  local rows key
  while :; do
    rows=$(ipc audio)
    key=$(choose "$rows" audio "$LIST") || return 0
    case $key in
    dev:*) ipc audioDefault "$key" >/dev/null ;;
    *) audio_level "$key" "$(label_of "$rows" "$key")" ;;
    esac
    sleep 0.2
  done
}

calendar_menu() {
  local rows key acts act text
  while :; do
    rows=$(ipc cal)
    key=$(choose "$rows" "calendar [$(ipc calState)]" "$LIST") || return 0
    case $key in
    add)
      text=$(printf '' | menu "new event (gym tomorrow 7pm)" 0) || continue
      [ -n "$text" ] && ipc calAdd "$text" >/dev/null
      ;;
    sync)
      ipc calSync >/dev/null
      sleep 2
      ;;
    *)
      acts=$(ipc calActions "$key")
      [ -n "$acts" ] || continue
      act=$(choose "$acts" "$(label_of "$rows" "$key")" "$LIST") || continue
      case $act in
      delete) [ "$(printf 'no\nyes\n' | menu "delete the event?" "$LIST")" = yes ] && ipc calAct "$key" delete >/dev/null ;;
      *)
        ipc calAct "$key" "$act" >/dev/null
        return 0
        ;;
      esac
      ;;
    esac
  done
}

vpn_rows() {
  local unit mark
  { systemctl list-unit-files --no-legend --plain 'wg-quick-*.service' 2>/dev/null || true; } | while read -r unit _; do
    unit=${unit%.service}
    mark='[ ]'
    systemctl is-active --quiet "$unit" && mark='[x]'
    printf 'vpn:%s\t%s vpn %s\n' "$unit" "$mark" "${unit#wg-quick-}"
  done
}

net_menu() {
  local key
  ipc netRefresh >/dev/null
  sleep 0.3
  while :; do
    key=$(choose "$(ipc net)" network "$LIST") || return 0
    case $key in
    stats)
      qs bare pop net
      return 0
      ;;
    ping | speed)
      ipc netAct "$key" >/dev/null
      qs bare pop net
      return 0
      ;;
    qr)
      ipc netAct qr >/dev/null
      qs bare pop qr
      return 0
      ;;
    dns:*)
      ipc netAct "$key" >/dev/null
      sleep 1.5
      ;;
    esac
  done
}

weather_menu() {
  local key q places i n=0
  key=$(choose "$(ipc weather)" weather "$LIST") || return 0
  case $key in
  forecast) qs bare pop weather ;;
  refresh)
    ipc weatherAct refresh >/dev/null
    qs bare pop weather
    ;;
  forget) ipc weatherAct forget >/dev/null ;;
  place)
    q=$(printf '' | menu city 0) || return 0
    [ -n "$q" ] || return 0
    ipc weatherSearch "$q" >/dev/null
    while [ "$n" -lt 40 ] && [ "$(ipc weatherSearching)" = yes ]; do
      sleep 0.25
      n=$((n + 1))
    done
    places=$(ipc weatherPlaces)
    if [ -z "$places" ]; then
      notify-send Weather "found no place called \"$q\""
      return 0
    fi
    i=$(choose "$places" place "$LIST") || return 0
    [ -n "$i" ] && ipc weatherPick "$i" >/dev/null
    ;;
  esac
}

seek_menu() {
  local sel spec
  sel=$(printf '%s\n' -10s +10s -30s +30s start | menu "seek (1:30, 50%, -5s)" "$LIST") || return 0
  case ${sel// /} in
  start) spec=0 ;;
  -*) spec="back:${sel//[!0-9]/}" ;;
  +*) spec="ahead:${sel//[!0-9]/}" ;;
  *) spec=${sel// /} ;;
  esac
  [ -n "$spec" ] && ipc mediaSeek "$spec" >/dev/null
}

media_menu() {
  local rows key
  while :; do
    rows=$(ipc media)
    if [ -z "$rows" ]; then
      notify-send Media "nothing is playing"
      return 0
    fi
    key=$(choose "$rows" "media [$(ipc mediaState)]" "$LIST") || return 0
    case $key in
    seek) seek_menu ;;
    players) act pin players player "$LIST" ;;
    *) ipc mediaAct "$key" >/dev/null ;;
    esac
    sleep 0.3
  done
}

display_menu() {
  local name=$1 key value prompt
  while :; do
    key=$(choose "$(ipc displayActions "$name")" "$(ipc display "$name")" "$LIST") || return 0
    case $key in
    disabled | reset) value="" ;;
    *)
      case $key in
      mode) prompt="$name resolution" ;;
      transform) prompt="$name rotation" ;;
      vrr) prompt="$name variable refresh" ;;
      *) prompt="$name $key" ;;
      esac
      value=$(choose "$(ipc displayOptions "$name" "$key")" "$prompt" "$LIST") || continue
      ;;
    esac
    case $(ipc displaySet "$name" "$key" "$value") in
    refused*) notify-send Displays "$name is the last screen on, it stays enabled" ;;
    esac
    sleep 1
    ipc displays >/dev/null
    sleep 0.3
  done
}

display_mode() {
  local mode
  mode=$(choose "$(ipc displayModes)" "displays mode" "$LIST") || return 0
  ipc displayMode "$mode" >/dev/null
  sleep 1
  ipc displays >/dev/null
  sleep 0.3
}

displays_menu() {
  local rows name
  rows=$(ipc displays)
  [ -n "$rows" ] || return 0
  if [ "$(printf '%s\n' "$rows" | wc -l)" -eq 1 ]; then
    display_menu "${rows%%$'\t'*}"
    return 0
  fi
  while name=$(choose "$rows" displays "$LIST"); do
    case $name in
    mode) display_mode ;;
    *) display_menu "$name" ;;
    esac
    rows=$(ipc displays)
  done
}

battery_label() {
  local bat
  for bat in /sys/class/power_supply/BAT*; do
    [ -r "$bat/capacity" ] || continue
    printf '%s%%, %s' "$(cat "$bat/capacity")" "$(tr '[:upper:]' '[:lower:]' <"$bat/status")"
    return 0
  done
  printf 'no battery'
}

PP=org.freedesktop.UPower.PowerProfiles
PP_PATH=/org/freedesktop/UPower/PowerProfiles

power_rows() {
  local now p label
  if now=$(busctl get-property "$PP" "$PP_PATH" "$PP" ActiveProfile 2>/dev/null); then
    now=${now#s \"}
    now=${now%\"}
    for p in $(busctl --json=short get-property "$PP" "$PP_PATH" "$PP" Profiles 2>/dev/null | jq -r '.data[].Profile.data'); do
      label="[ ] ${p//-/ }"
      [ "$p" = "$now" ] && label="[x] ${p//-/ }"
      printf 'profile:%s\t%s\n' "$p" "$label"
    done
  fi
  printf '%s\n' $'battery\tshow battery details' $'lock\tlock' $'suspend\tsuspend' $'logout\tlogout' $'reboot\treboot' \
    $'windows\treboot into windows' $'uefi\treboot into uefi' $'poweroff\tpoweroff'
}

clip_delete() {
  local id
  while id=$(choose "$(cliphist list)" "delete" "$LIST"); do
    [ -n "$id" ] && printf '%s\n' "$id" | cliphist delete
  done
}

wifi_rows() {
  nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan "$1" 2>/dev/null |
    awk -F: 'NF>=4 && $4!="" && !seen[$4]++ {
      s=$4; for (i = 5; i <= NF; i++) s = s ":" $i; gsub(/\\:/, ":", s);
      printf "%s\t%s %3s%% %s%s\n", s, ($1 == "*" ? "[x]" : "[ ]"), $2, s, ($3 == "" ? " (open)" : "") }' |
    LC_ALL=C sort -t"	" -k2,2r
}

paths() { sed 's|.*|&\t|' | sed 's|^\(.*\)/\([^/]*\)\t$|\1/\2\t\2|'; }

case "${1:-}" in
"" | list) ;;
*) claim ;;
esac

case "${1:-}" in
run | apps)
  rows=$(ipc apps)
  rc=0
  sel=$(printf '%s\n' "$rows" | cut -f2- | menu run 0 -A) || rc=$?
  [ "$rc" -eq 0 ] || [ "$rc" -eq 10 ] || exit 0
  [ -n "$sel" ] || exit 0
  key=$(printf '%s\n' "$rows" | awk -F'\t' -v s="$sel" 'substr($0, index($0, "\t") + 1) == s { print $1; exit }')
  if [ -n "$key" ] && [ "${sel#\?}" = "$sel" ] && [ "$rc" -eq 10 ]; then
    ipc launch "$key" >/dev/null
  elif [ -n "$key" ] && [ "${sel#\?}" = "$sel" ]; then
    order=$(hyprctl clients -j | jq -r 'sort_by(.focusHistoryID == 0, .focusHistoryID < 0, .focusHistoryID) | map(.address) | join(" ")')
    ipc open "$key" "$order" >/dev/null
  else
    sel=${sel#\?}
    sel=${sel# }
    [ -n "$sel" ] && exec qutebrowser "$sel"
  fi
  ;;
windows)
  addr=$(choose "$(window_rows)" window "$LIST") || exit 0
  [ -n "$addr" ] && ipc focus "$addr" >/dev/null
  ;;
tray)
  id=$(choose "$(ipc tray)" tray "$LIST") || exit 0
  [ -n "$id" ] && tray_menu "$id"
  ;;
media) media_menu ;;
power)
  key=$(choose "$(power_rows)" "power [$(battery_label)]" "$LIST") || exit 0
  case $key in
  profile:*) busctl set-property "$PP" "$PP_PATH" "$PP" ActiveProfile s "${key#profile:}" ;;
  battery) qs bare pop battery ;;
  lock) quickshell ipc call lock lock ;;
  suspend) systemctl suspend ;;
  logout) hyprctl dispatch 'hl.dsp.exit()' ;;
  reboot) systemctl reboot ;;
  windows) systemctl reboot --boot-loader-entry=auto-windows ;;
  uefi) systemctl reboot --firmware-setup ;;
  poweroff) systemctl poweroff ;;
  esac
  ;;
clip)
  rows=$(cliphist list)
  id=$(choose "${rows:+$rows$'\n'}"$'delete\tdelete an entry\nwipe\twipe the history' clip "$LIST") || exit 0
  case $id in
  delete) clip_delete ;;
  wipe) [ "$(printf 'no\nyes\n' | menu "wipe the whole history?" "$LIST")" = yes ] && cliphist wipe ;;
  ?*) printf '%s' "$id" | cliphist decode | wl-copy ;;
  esac
  ;;
theme)
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/bare-pick/theme"
  width=$(hyprctl monitors -j | jq '.[] | select(.focused) | .width / .scale / 10 | floor')
  theme-set previews "$cache" "${width:-192}" || true
  sel=$(theme-set list | sed 's/^[* ]*//' | menu theme "$LIST" -I "$cache")
  [ -n "$sel" ] && theme-set "$sel"
  ;;
wall)
  dir="$HOME/pictures/wallpapers"
  plates="${XDG_DATA_HOME:-$HOME/.local/share}/theme-engine/plates"
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/bare-pick/wall"
  names=$(find -L "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)
  plate_names=$(find -L "$plates" -maxdepth 1 -type f -name '*.jpg' -printf 'plates/%f\n' 2>/dev/null | sort)
  mkdir -p "$cache/plates"
  for p in $plate_names; do
    [ -f "$cache/$p" ] || gdk-pixbuf-thumbnailer -s 640 "$plates/${p#plates/}" "$cache/$p" || rm -f "$cache/$p"
  done
  find "$cache" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | while IFS= read -r n; do
    if [ ! -e "$dir/$n" ]; then rm -f -- "$cache/$n"; fi
  done
  stale=$(printf '%s\n' "$names" | while IFS= read -r n; do
    if [ -n "$n" ] && { [ ! -f "$cache/$n" ] || [ "$dir/$n" -nt "$cache/$n" ]; }; then
      printf '%s\n' "$n"
    fi
  done)
  if [ -n "$stale" ]; then
    # shellcheck disable=SC2016
    printf '%s\n' "$stale" | xargs -d '\n' -P 4 -I {} sh -c \
      'gdk-pixbuf-thumbnailer -s 640 "$1/$3" "$2/.$3.tmp" && mv -f "$2/.$3.tmp" "$2/$3" || rm -f "$2/.$3.tmp"' \
      _ "$dir" "$cache" {}
  fi
  state="$HOME/.local/state/quickshell"
  recolor=on
  [ "$(cat "$state/wallpaper-recolor" 2>/dev/null)" = 0 ] && recolor=off
  while :; do
    mark=' '
    [ "$recolor" = on ] && mark=x
    sel=$(printf '[%s] recolor\n%s\n%s\n' "$mark" "$names" "$plate_names" | menu wallpaper 10 -I "$cache") || exit 0
    case $sel in
    "") exit 0 ;;
    "[x] recolor") recolor=off ;;
    "[ ] recolor") recolor=on ;;
    esac
    flag=()
    [ "$recolor" = off ] && flag=(--no-recolor)
    case $sel in
    "[x] recolor" | "[ ] recolor")
      src=$(cat "$state/wallpaper-source" 2>/dev/null) || src=
      if [ -n "$src" ]; then
        theme-set wallpaper "$src" "${flag[@]}"
      else
        mkdir -p "$state"
        if [ "$recolor" = on ]; then echo 1; else echo 0; fi >"$state/wallpaper-recolor"
      fi
      ;;
    plates/*)
      theme-set wallpaper "$plates/${sel#plates/}" "${flag[@]}"
      exit 0
      ;;
    *)
      theme-set wallpaper "$dir/$sel" "${flag[@]}"
      exit 0
      ;;
    esac
  done
  ;;
wifi)
  wdev=$(nmcli -t -f TYPE,DEVICE device status 2>/dev/null |
    awk -F: '$1=="wifi"{print $2; exit}')
  current=$(nmcli -t -f DEVICE,NAME connection show --active 2>/dev/null |
    awk -F: -v d="$wdev" '$1==d{sub(/^[^:]*:/,""); gsub(/\\:/,":"); print; exit}')
  { nmcli device wifi rescan >/dev/null 2>&1 || true; } &
  mode=no
  while :; do
    rows=$(wifi_rows "$mode")
    sel=$(choose "${rows:+$rows$'\n'}"$':rescan\trescan' wifi "$LIST") || exit 0
    [ "$sel" = :rescan ] || break
    mode=auto
  done
  [ -n "$sel" ] || exit 0
  if [ "$sel" = "$current" ]; then
    case $(printf 'disconnect\nforget this network\n' | menu "\"$sel\"" "$LIST") in
    disconnect) nmcli connection down id "$sel" ;;
    "forget this network") nmcli connection delete id "$sel" ;;
    esac
  elif nmcli -t -f NAME connection show 2>/dev/null | sed 's/\\:/:/g' | grep -qxF "$sel"; then
    nmcli connection up id "$sel"
  elif nmcli -t -f SECURITY,SSID device wifi list --rescan no 2>/dev/null |
    awk -F: -v s="$sel" 'NF>=2 { t=$2; for (i = 3; i <= NF; i++) t = t ":" $i; gsub(/\\:/, ":", t);
      if (t == s) { print $1; exit } }' | grep -qx ''; then
    nmcli device wifi connect "$sel"
  else
    pw=$(printf '' | menu "\"$sel\" password" 0 -P) || exit 0
    [ -n "$pw" ] || exit 0
    nmcli device wifi connect "$sel" password "$pw"
  fi
  ;;
send) send ;;
calc) calc ;;
timer) timer ;;
net) net_menu ;;
weather) weather_menu ;;
monitor) qs bare pop monitor ;;
displays) displays_menu ;;
control) control_menu ;;
bt) bt_menu ;;
audio) audio_menu ;;
calendar) calendar_menu ;;
notes) exec note ;;
record)
  mode=$(choose $'none\tno audio\nsystem\tsystem audio\nmic\tmicrophone\nboth\tsystem audio and microphone' record "$LIST") || exit 0
  [ -n "$mode" ] && exec record "$mode"
  ;;
shelf) shelf ;;
home)
  rows=$({
    printf '%s\n' $'run\tapps\nwindows\twindows\nrepos\trepositories\nclip\tclipboard\nshelf\tfiles shelf\nsend\tsend with localsend\nnotes\tnotes\ncalendar\tcalendar'
    extras | sed 's/.*/&\t&/'
    printf '%s\n' $'timer\ttimer\ncalc\tcalculator\ncontrol\tcontrol\nwifi\twifi\nbt\tbluetooth\naudio\taudio\nnet\tnetwork tools\ndisplays\tdisplays\nmedia\tmedia\nrecord\trecord the screen\nweather\tweather\nmonitor\tsystem monitor\nwall\twallpaper\ntheme\ttheme\ntray\ttray\npower\tpower'
  })
  sel=$(choose "$rows" menu "$LIST") || exit 0
  [ -n "$sel" ] && exec "$0" "$sel"
  ;;
repos)
  rows=$(find -L "$HOME/repos" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | paths)
  sel=$(choose "$rows" repo "$LIST") || exit 0
  [ -n "$sel" ] && kitty --directory "$sel" -e nvim .
  ;;
"" | list)
  printf '%s\n' run windows tray media power clip theme wall wifi send repos calc timer shelf home record control bt audio calendar
  extras
  printf '%s\n' notes net weather monitor displays
  ;;
*)
  if [ -f "$EXTRA/$1.sh" ]; then
    # shellcheck disable=SC1090
    source "$EXTRA/$1.sh"
  else
    echo "bare-pick: unknown source '$1'" >&2
    exit 1
  fi
  ;;
esac
