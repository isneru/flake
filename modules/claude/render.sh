#!/usr/bin/env bash
kind=$1 src=$2 out=$3 color=$4
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

case $kind in
math)
  body=$(sed -E \
    -e 's/\\(begin|end)\{(align|alignat|flalign|split)\*?\}/\\\1{aligned}/g' \
    -e 's/\\(begin|end)\{(gather|multline)\*?\}/\\\1{gathered}/g' \
    -e 's/\\(begin|end)\{equation\*?\}//g' \
    -e 's/\\tag\*\{([^}]*)\}/\\qquad\\text{\1}/g' \
    -e 's/\\tag\{([^}]*)\}/\\qquad\\text{(\1)}/g' "$src")
  # shellcheck disable=SC1003
  if [[ $body == *'\\'* && $body != *'\begin'* ]]; then
    body="\\begin{gathered}$body\\end{gathered}"
  fi
  cat >"$tmp/m.tex" <<TEX
\\documentclass{article}\\usepackage{amsmath,amssymb,mathtools,bm,cancel,mathrsfs,pifont,xcolor}\\usepackage[only,llbracket,rrbracket]{stmaryrd}
\\begin{document}\\setbox0\\hbox{\$\\displaystyle $body\$}
\\pdfpagewidth=\\dimexpr\\wd0+2pt\\relax \\pdfpageheight=\\dimexpr\\ht0+\\dp0+2pt\\relax
\\pdfhorigin=1pt \\pdfvorigin=1pt \\shipout\\vbox{\\box0}\\end{document}
TEX
  if ! pdflatex -interaction=nonstopmode -halt-on-error -output-directory "$tmp" "$tmp/m.tex" >"$tmp/log" 2>&1; then
    grep -m1 -A1 '^!' "$tmp/log" >&2 || echo "pdflatex failed" >&2
    exit 1
  fi
  printf '#set page(width: auto, height: auto, margin: 0pt, fill: none)\n#image("m.pdf")\n' >"$tmp/w.typ"
  typst compile --ppi 288 "$tmp/w.typ" "$tmp/m.png" >&2
  magick "$tmp/m.png" -fill "$color" -colorize 100 "$out"
  ;;
plantuml)
  plantuml -pipe -tpng -darkmode <"$src" >"$tmp/d.png" 2>"$tmp/err" || {
    head -3 "$tmp/err" >&2
    exit 1
  }
  mv "$tmp/d.png" "$out"
  ;;
mermaid)
  cat >"$tmp/c.json" <<'JSON'
{
  "themeVariables": {
    "xyChart": {
      "backgroundColor": "transparent",
      "titleColor": "#e4e4e4",
      "xAxisTitleColor": "#e4e4e4",
      "xAxisLabelColor": "#e4e4e4",
      "xAxisTickColor": "#808080",
      "xAxisLineColor": "#808080",
      "yAxisTitleColor": "#e4e4e4",
      "yAxisLabelColor": "#e4e4e4",
      "yAxisTickColor": "#808080",
      "yAxisLineColor": "#808080",
      "plotColorPalette": "#5fafff,#ffaf5f,#87d787,#d7afff,#ff5f87,#5fd7d7,#d7d75f,#af87ff"
    },
    "pie1": "#5fafff",
    "pie2": "#ffaf5f",
    "pie3": "#87d787",
    "pie4": "#d7afff",
    "pie5": "#ff5f87",
    "pie6": "#5fd7d7",
    "pie7": "#d7d75f",
    "pie8": "#af87ff",
    "pieStrokeColor": "#1c1c1c",
    "pieOuterStrokeColor": "#1c1c1c",
    "pieOpacity": "1",
    "pieSectionTextColor": "#1c1c1c",
    "pieTitleTextColor": "#e4e4e4",
    "pieLegendTextColor": "#e4e4e4"
  }
}
JSON
  mmdc -q -i "$src" -o "$tmp/d.png" -t dark -b transparent -s 2 -c "$tmp/c.json" >&2
  mv "$tmp/d.png" "$out"
  ;;
esac

magick identify -format '%w %h' "$out"
