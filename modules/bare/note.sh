notes="$HOME/notes"
groups=()
list="${XDG_CONFIG_HOME:-$HOME/.config}/bare/notebooks"
[ -f "$list" ] && mapfile -t groups <"$list"
slug() { printf '%s' "$1" | tr -s '/[:space:]' '-' | sed 's/^-//; s/-$//'; }
dirs() { find -L "$1" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' 2>/dev/null | sort || true; }
grouped() {
  local g
  for g in "${groups[@]}"; do
    dirs "$notes/$g" | grep -vx archive || true
  done
}

home=""
book=${1:-}
if [ "${book#/}" != "$book" ]; then
  home=$book
  book=${book##*/}
elif [ -z "$book" ]; then
  courses=$(grouped)
  others=$(dirs "$notes" | grep -vxF -f <(printf '%s\n' "${groups[@]}" "$courses") || true)
  books=$(printf '%s\n%s\n' "$courses" "$others" | sed '/^$/d')

  if [ -n "$books" ]; then
    book=$(printf '%s\n' "$books" | bare-menu -c -p "notebook: " -l 20) || exit 0
  else
    book=$(bare-menu -p "notebook: " -l 0 </dev/null) || exit 0
  fi
fi
book=$(slug "$book")
[ -n "$book" ] || exit 0

topic=$(bare-menu -p "$book topic: " -l 0 </dev/null) || exit 0
name=$(slug "$topic")
[ -n "$name" ] || exit 0

if [ -z "$home" ]; then
  for g in "${groups[@]}"; do
    [ -d "$notes/$g/$book" ] && home="$notes/$g/$book" && break
  done
fi
if [ -n "$home" ]; then
  dir="$home/notes/$(date +%F)"
else
  home="$notes/$book"
  dir="$home/$(date +%F)"
fi
file="$dir/$name.md"
mkdir -p "$dir"
[ -e "$file" ] || printf '# %s\n\n' "$(printf '%s' "$topic" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')" >"$file"

exec kitty --directory "$home" -e nvim + "$file"
