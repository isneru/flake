import colorsys
import json
import sys

import tomllib

HUES = [
    (20, "red"),
    (70, "yellow"),
    (165, "green"),
    (195, "cyan"),
    (260, "blue"),
    (345, "magenta"),
    (360, "red"),
]


def ansi(hex_colour):
    """Return the ANSI colour name nearest in hue to a #rrggbb colour."""
    r, g, b = (int(hex_colour[i : i + 2], 16) / 255 for i in (1, 3, 5))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.25:
        return "white" if v > 0.85 else "gray"
    return next(name for limit, name in HUES if h * 360 < limit)


def entry(rule):
    fields = []
    for key, value in rule.items():
        if key == "fg" and value.startswith("#"):
            value = ansi(value)
        fields.append(f"{key} = {json.dumps(value, ensure_ascii=False)}")
    return "\t{ " + ", ".join(fields) + " },"


with open(sys.argv[1], "rb") as f:
    icons = tomllib.load(f)["icon"]

BORDER = '{ fg = "240" }'
SQUARE = '{ open = "\u2588", close = "\u2588" }'

print("[mgr]")
print(f"border_style = {BORDER}")
print("[tabs]")
print(f"sep_inner = {SQUARE}")
print(f"sep_outer = {SQUARE}")
print("[indicator]")
print(f"padding = {SQUARE}")
print("[status]")
print(f"sep_left = {SQUARE}")
print(f"sep_right = {SQUARE}")
for popup in ("which", "confirm", "spot", "pick", "input", "cmp", "tasks", "help"):
    print(f"[{popup}]")
    print(f"border = {BORDER}")
print("[icon]")
for section, rules in icons.items():
    print(f"{section} = [")
    print(*map(entry, rules), sep="\n")
    print("]")
