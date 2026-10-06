key=/org/gnome/desktop/interface/gtk-theme

if [ "$(dconf read "$key")" = "'$NAME-a'" ]; then
  slot=$NAME-b
else
  slot=$NAME-a
fi

base=$ADW/$(cat "$SCHEME")
dir=$THEMES/$slot
rm -rf "$dir"
mkdir -p "$dir/gtk-3.0" "$dir/gtk-4.0"
{
  printf '@import url("file://%s/gtk-3.0/gtk.css");\n' "$base"
  cat "$COLORS"
} >"$dir/gtk-3.0/gtk.css"
printf '@import url("file://%s/gtk-4.0/gtk.css");\n' "$base" >"$dir/gtk-4.0/gtk.css"

dconf write "$key" "'$slot'"
