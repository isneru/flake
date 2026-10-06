notes="$HOME/notes"
isep="$notes/isep"
slug() { printf '%s' "$1" | tr -s '/[:space:]' '-' | sed 's/^-//; s/-$//'; }
dirs() { find -L "$1" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' 2>/dev/null | sort || true; }

book=${1:-}
if [ -z "$book" ]; then
  courses=$(dirs "$isep" | grep -vx archive || true)
  others=$(dirs "$notes" | grep -vxF -e isep -f <(printf '%s\n' "$courses") || true)
  books=$(printf '%s\n%s\n' "$courses" "$others" | sed '/^$/d')

  if [ -n "$books" ]; then
    book=$(printf '%s\n' "$books" | notch-menu -c -p "notebook: " -l 20) || exit 0
  else
    book=$(notch-menu -p "notebook: " -l 0 </dev/null) || exit 0
  fi
fi
book=$(slug "$book")
[ -n "$book" ] || exit 0

topic=$(notch-menu -p "$book topic: " -l 0 </dev/null) || exit 0
name=$(slug "$topic")
[ -n "$name" ] || exit 0

if [ -n "${1:-}" ] || [ -d "$isep/$book" ]; then
  home="$isep/$book"
  dir="$home/notes/$(date +%F)"
else
  home="$notes/$book"
  dir="$home/$(date +%F)"
fi
file="$dir/$name.md"
mkdir -p "$dir"
[ -e "$file" ] || printf '# %s\n\n' "$(printf '%s' "$topic" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')" >"$file"

exec kitty --directory "$home" -e nvim + "$file"
