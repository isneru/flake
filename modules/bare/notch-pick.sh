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
  local pidfile="${XDG_RUNTIME_DIR:-/tmp}/notch-pick.pid" old kids
  exec 9>"$pidfile.lock"
  flock 9
  old=$(cat "$pidfile" 2>/dev/null || true)
  if [ -n "$old" ] && [ "$old" != $$ ] && grep -qa notch-pick /proc/"$old"/cmdline 2>/dev/null; then
    kids=$(descendants "$old")
    # shellcheck disable=SC2086
    kill "$old" $kids 2>/dev/null || true
  fi
  echo $$ >"$pidfile"
  flock -u 9
  exec 9>&-
}

LIST=20
ISEP="$HOME/notes/isep"

menu() {
  local prompt=$1 lines=$2
  shift 2
  if [ "$lines" -gt 0 ]; then
    notch-menu -c -p "$prompt: " -l "$lines" "$@"
  else
    notch-menu -p "$prompt: " -l 0 "$@"
  fi
}

choose() {
  local rows=$1 prompt=$2 lines=$3 sel
  [ -n "$rows" ] || return 1
  sel=$(printf '%s\n' "$rows" | cut -f2- | menu "$prompt" "$lines") || return 1
  [ -n "$sel" ] || return 1
  printf '%s\n' "$rows" | awk -F'\t' -v s="$sel" 'substr($0, index($0, "\t") + 1) == s { print $1; exit }'
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
    | (if $c == "kitty" and (.title | endswith(" - Nvim")) then ["nvim", (.title | sub(" - Nvim$"; ""))]
      elif $c == "qutebrowser" then [$c, (.title | sub(" - qutebrowser$"; ""))]
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
    *) prompt="send ($state)" ;;
    esac
    rows=""
    [ -n "$state" ] && rows+=$'to\tsend to a device\n'
    rows+=$'file\tadd a file\nclipboard\tadd the clipboard\nshelf\tadd the shelf\ntext\twrite a message\n'
    [ -n "$state" ] && rows+=$'clear\tclear\n'
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

control_menu() {
  local key
  while :; do
    key=$(choose "$(ipc control)" "control [$(ipc controlState)]" "$LIST") || return 0
    case $key in
    networks) exec "$0" wifi ;;
    devices) exec "$0" bt ;;
    audio) exec "$0" audio ;;
    nightTemp) night_temp ;;
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
      act=$(choose "$acts" "$(label_of "$rows" "$key")" "$LIST") || continue
      ipc btAct "$key" "$act" >/dev/null
      sleep 1
      ;;
    esac
  done
  ipc btStopScan >/dev/null
}

audio_level() {
  local sel
  sel=$(printf '%s\n' 'toggle mute' 100% 75% 50% 25% | menu "$2" "$LIST") || return 0
  case $sel in
  "toggle mute") ipc audioMute "$1" >/dev/null ;;
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

notifs_menu() {
  local rows key acts act
  while :; do
    rows=$(ipc notifs)
    key=$(choose "$rows" notifications "$LIST") || return 0
    case $key in
    dnd) ipc controlToggle dnd >/dev/null ;;
    clear)
      ipc notifClear >/dev/null
      return 0
      ;;
    *)
      acts=$(ipc notifActions "$key")
      [ -n "$acts" ] || continue
      act=$(choose "$acts" "$(label_of "$rows" "$key")" "$LIST") || continue
      ipc notifAct "$key" "$act" >/dev/null
      [ "$act" = dismiss ] || return 0
      ;;
    esac
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
      delete) [ "$(printf 'no\nyes\n' | menu "delete it?" "$LIST")" = yes ] && ipc calAct "$key" delete >/dev/null ;;
      *)
        ipc calAct "$key" "$act" >/dev/null
        return 0
        ;;
      esac
      ;;
    esac
  done
}

deadline_rows() {
  local f meta due title course when late now
  now=$(date '+%Y-%m-%d %H:%M')
  for f in "$ISEP"/*/deadlines/*.md; do
    [ -f "$f" ] || continue
    meta=$(awk '
      /^---$/ && n < 2 { n++; next }
      n == 1 && /^due:/ { d = $0; sub(/^due:[ \t]*/, "", d); gsub(/["\047]/, "", d) }
      n == 2 && t == "" && /^#[ \t]/ { t = $0; sub(/^#[ \t]+/, "", t) }
      END { print d "\t" t }' "$f")
    due=${meta%%$'\t'*}
    title=${meta#*$'\t'}
    course=${f%/deadlines/*}
    course=${course##*/}
    late=""
    if [[ $due =~ ^([0-9]{2})/([0-9]{2})/([0-9]{4})\ ([0-9]{2}:[0-9]{2})$ ]] &&
      due="${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]} ${BASH_REMATCH[4]}" &&
      when=$(date -d "$due" '+%a %-d %b %H:%M' 2>/dev/null); then
      [[ $due < $now ]] && late=" (overdue)"
    else
      due="0000"
      when="?"
      late=" (due not understood)"
    fi
    printf '%s\t%s\t%s [%s] "%s"%s\n' "$due" "$f" "$when" "${course^^}" "${title:-$(basename "$f" .md)}" "$late"
  done | sort | cut -f2-
}

new_deadline() {
  local course title prompt text when due slug file
  course=$({ find -L "$ISEP" -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name archive -printf '%f\n' 2>/dev/null | sort || true; } | menu course "$LIST") || return 1
  [ -n "$course" ] && [ -d "$ISEP/$course" ] || return 1
  title=$(printf '' | menu "${course^^} deadline" 0) || return 1
  [ -n "$title" ] || return 1
  prompt="due (20/10/2026 23:59, 20/10 23:59, fri 23:59)"
  while :; do
    text=$(printf '' | menu "$prompt" 0) || return 1
    when=$text
    if [[ $text =~ ^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})(.*)$ ]]; then
      when="${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}${BASH_REMATCH[4]}"
    elif [[ $text =~ ^([0-9]{1,2})/([0-9]{1,2})(.*)$ ]]; then
      when="${BASH_REMATCH[2]}/${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
    fi
    [ -n "$text" ] && due=$(date -d "$when" '+%d/%m/%Y %H:%M' 2>/dev/null) && break
    prompt="due (\"$text\" not understood)"
  done
  slug=$(printf '%s' "$title" | tr -s '/[:space:]' '-' | sed 's/^-//; s/-$//')
  file="$ISEP/$course/deadlines/$slug.md"
  mkdir -p "${file%/*}"
  [ -e "$file" ] || printf -- '---\ndue: %s\n---\n# %s\n\n' "$due" "$title" >"$file"
  exec kitty --directory "$ISEP/$course" -e nvim + "$file"
}

deadline_item() {
  local f=$1
  case $(printf 'open\nmark done\n' | menu "$2" "$LIST") in
  open) exec kitty --directory "${f%/deadlines/*}" -e nvim "$f" ;;
  "mark done")
    mkdir -p "${f%/*}/done"
    mv -n "$f" "${f%/*}/done/"
    ;;
  esac
}

deadlines_menu() {
  local rows key
  while :; do
    rows=$(deadline_rows)
    key=$(choose $'new\tnew deadline'"${rows:+$'\n'$rows}" deadlines "$LIST") || return 0
    case $key in
    new) new_deadline ;;
    *) deadline_item "$key" "$(label_of "$rows" "$key")" ;;
    esac
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
      qs notch open netstats
      return 0
      ;;
    ping | speed)
      ipc netAct "$key" >/dev/null
      qs notch open netstats
      return 0
      ;;
    qr)
      ipc netAct qr >/dev/null
      qs notch open wifiqr
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
  forecast) qs notch open weather ;;
  refresh)
    ipc weatherAct refresh >/dev/null
    qs notch open weather
    ;;
  forget) ipc weatherAct forget >/dev/null ;;
  place)
    q=$(printf '' | menu "search a city" 0) || return 0
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

paths() { sed 's|.*|&\t|' | sed 's|^\(.*\)/\([^/]*\)\t$|\1/\2\t\2|'; }

case "${1:-}" in
"" | list) ;;
*) claim ;;
esac

case "${1:-}" in
run | apps) act launch apps run 0 ;;
windows)
  addr=$(choose "$(window_rows)" window "$LIST") || exit 0
  [ -n "$addr" ] && ipc focus "$addr" >/dev/null
  ;;
tray)
  id=$(choose "$(ipc tray)" tray "$LIST") || exit 0
  [ -n "$id" ] && tray_menu "$id"
  ;;
media) act pin players player "$LIST" ;;
power)
  case $(printf 'lock\nsuspend\nlogout\nreboot\nreboot into windows\nreboot into uefi\npoweroff\n' | menu power "$LIST") in
  lock) quickshell ipc call lock lock ;;
  suspend) systemctl suspend ;;
  logout) hyprctl dispatch 'hl.dsp.exit()' ;;
  reboot) systemctl reboot ;;
  "reboot into windows") systemctl reboot --boot-loader-entry=auto-windows ;;
  "reboot into uefi") systemctl reboot --firmware-setup ;;
  poweroff) systemctl poweroff ;;
  esac
  ;;
clip)
  id=$(choose "$(cliphist list)" clip "$LIST") || exit 0
  [ -n "$id" ] && printf '%s' "$id" | cliphist decode | wl-copy
  ;;
theme)
  sel=$(theme-set list | sed 's/^[* ]*//' | menu theme "$LIST")
  [ -n "$sel" ] && theme-set "$sel"
  ;;
wall)
  dir="$HOME/pictures/wallpapers"
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/notch-pick/wall"
  names=$(find -L "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)
  mkdir -p "$cache"
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
  sel=$(printf '%s\n' "$names" | menu wallpaper 10 -I "$cache") || exit 0
  [ -n "$sel" ] && theme-set wallpaper "$dir/$sel"
  ;;
wifi)
  wdev=$(nmcli -t -f TYPE,DEVICE device status 2>/dev/null |
    awk -F: '$1=="wifi"{print $2; exit}')
  current=$(nmcli -t -f DEVICE,NAME connection show --active 2>/dev/null |
    awk -F: -v d="$wdev" '$1==d{sub(/^[^:]*:/,""); gsub(/\\:/,":"); print; exit}')
  sel=$(choose "$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes 2>/dev/null |
    awk -F: 'NF>=4 && $4!="" && !seen[$4]++ {
      s=$4; for (i = 5; i <= NF; i++) s = s ":" $i; gsub(/\\:/, ":", s);
      printf "%s\t%s %3s%%  %s%s\n", s, ($1 == "*" ? "*" : " "), $2, s, ($3 == "" ? "  (open)" : "") }' |
    LC_ALL=C sort -t"	" -k2,2r)" wifi "$LIST") || exit 0
  [ -n "$sel" ] || exit 0
  if [ "$sel" = "$current" ]; then
    case $(printf 'disconnect\nforget\n' | menu "$sel" "$LIST") in
    disconnect) nmcli connection down id "$sel" ;;
    forget) nmcli connection delete id "$sel" ;;
    esac
  elif nmcli -t -f NAME connection show 2>/dev/null | sed 's/\\:/:/g' | grep -qxF "$sel"; then
    nmcli connection up id "$sel"
  elif nmcli -t -f SECURITY,SSID device wifi list 2>/dev/null |
    awk -F: -v s="$sel" 'NF>=2 { t=$2; for (i = 3; i <= NF; i++) t = t ":" $i; gsub(/\\:/, ":", t);
      if (t == s) { print $1; exit } }' | grep -qx ''; then
    nmcli device wifi connect "$sel"
  else
    pw=$(printf '' | menu "$sel password" 0 -P) || exit 0
    [ -n "$pw" ] || exit 0
    nmcli device wifi connect "$sel" password "$pw"
  fi
  ;;
send) send ;;
calc) calc ;;
timer) timer ;;
net) net_menu ;;
weather) weather_menu ;;
monitor) qs notch open monitor ;;
displays) qs notch open display ;;
control) control_menu ;;
bt) bt_menu ;;
audio) audio_menu ;;
notifs) notifs_menu ;;
calendar) calendar_menu ;;
deadlines) deadlines_menu ;;
notes) exec note ;;
record)
  mode=$(choose $'none\tno audio\nsystem\tsystem audio\nmic\tmicrophone\nboth\tsystem + microphone' record "$LIST") || exit 0
  [ -n "$mode" ] && exec record "$mode"
  ;;
shelf) shelf ;;
home)
  sel=$(choose $'run\tapps\nwindows\twindows\nclip\tclipboard\nshelf\tfiles shelf\nsend\tsend with localsend\ntimer\ttimer\nrecord\trecord the screen\ncontrol\tcontrol\nwifi\twifi\nbt\tbluetooth\naudio\taudio\nnotifs\tnotifications\ncalendar\tcalendar\ndeadlines\tdeadlines\nnotes\tnotes\nweather\tweather\nnet\tnetwork tools\nmonitor\tsystem monitor\ndisplays\tdisplays\ncalc\tcalculator\nmedia\tmedia players\ntray\ttray\nwall\twallpaper\ntheme\ttheme\nrepos\trepositories\npower\tpower' menu "$LIST") || exit 0
  [ -n "$sel" ] && exec "$0" "$sel"
  ;;
repos)
  rows=$(find -L "$HOME/repos" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | paths)
  sel=$(choose "$rows" repo "$LIST") || exit 0
  [ -n "$sel" ] && kitty --directory "$sel" -e nvim .
  ;;
"" | list)
  printf '%s\n' run windows tray media power clip theme wall wifi send repos calc timer shelf home record control bt audio notifs calendar deadlines notes net weather monitor displays
  ;;
*)
  echo "notch-pick: unknown source '$1'" >&2
  exit 1
  ;;
esac
