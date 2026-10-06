freeze
region="$(slurp -w 2 -b '#00000066' -c '#FFFFFFFF' -s '#FFFFFF26')" || exit 0
sleep 0.2
text="$({
  grim -g "$region" -
  thaw
} | tesseract - - 2>/dev/null)"

if [[ -z $text ]]; then
  notify-send -e "OCR" "No text found" -a "OCR"
  exit 0
fi

printf '%s' "$text" | wl-copy

preview="$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-200)"
notify-send -e "OCR" "$preview" -a "OCR"
