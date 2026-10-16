ISEP="$HOME/notes/isep"

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
    key=$(choose $'new\tadd a deadline'"${rows:+$'\n'$rows}" deadlines "$LIST") || return 0
    case $key in
    new) new_deadline ;;
    *) deadline_item "$key" "$(label_of "$rows" "$key")" ;;
    esac
  done
}

deadlines_menu
