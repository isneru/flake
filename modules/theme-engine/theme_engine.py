#!/usr/bin/env python3

import colorsys
import fcntl
import glob
import json
import math
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from contextlib import contextmanager
from pathlib import Path

import tomllib

HEX_RE = re.compile(r"^#([0-9a-fA-F]{6})$")
TOKEN_RE = re.compile(r"\{\{(\w+)\}\}")
FAMILY_RE = re.compile(r"^[\w .\-]+$")

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
ENGINE_DIR = CONFIG_HOME / "theme-engine"
THEMES_DIR = ENGINE_DIR / "themes"
TEMPLATES_DIR = ENGINE_DIR / "templates"
APPS_FILE = ENGINE_DIR / "apps.json"
CURRENT_FILE = ENGINE_DIR / "current"
OVERRIDES_FILE = ENGINE_DIR / "overrides.toml"
RUN_DIR = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "theme-engine"
REQUEST_FILE = RUN_DIR / "request"
RENDERED_FILE = RUN_DIR / "rendered"
DEFAULT_THEME = "mocha"
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
PLATES_DIR = DATA_HOME / "theme-engine" / "plates"
PLATE_CACHE_DIR = CACHE_HOME / "theme-engine" / "plates"
RECOLOR_CACHE_DIR = CACHE_HOME / "theme-engine" / "wallpapers-recolored"
CURRENT_WALLPAPER_FILE = Path.home() / ".local" / "state" / "quickshell" / "wallpaper"
CURRENT_WALLPAPER_SOURCE_FILE = (
    Path.home() / ".local" / "state" / "quickshell" / "wallpaper-source"
)
CURRENT_WALLPAPER_RECOLOR_FILE = (
    Path.home() / ".local" / "state" / "quickshell" / "wallpaper-recolor"
)
SDDM_WALLPAPER = Path("/var/lib/sddm-theme/wallpaper.png")

REQUIRED_TOKENS = [
    "bg",
    "bgDim",
    "bgAlt",
    "border",
    "fg",
    "fgDim",
    "fgMuted",
    "accent",
    "error",
    "warning",
    "success",
    "info",
    "black",
    "brightBlack",
    "red",
    "brightRed",
    "green",
    "brightGreen",
    "yellow",
    "brightYellow",
    "blue",
    "brightBlue",
    "magenta",
    "brightMagenta",
    "cyan",
    "brightCyan",
    "white",
    "brightWhite",
    "mono",
    "size",
    "sizeUi",
    "radius",
]

NUMERIC_TOKENS = ("size", "sizeUi", "radius")
FAMILY_TOKENS = ("mono", "chrome")
OPTIONAL_TOKENS = ("chrome", "plateInk", "platePaper")


def warn(msg: str) -> None:
    print(f"theme-set: warning: {msg}", file=sys.stderr)


def load_apps() -> dict[str, dict]:
    if not APPS_FILE.is_file():
        sys.exit(f"theme-set: {APPS_FILE} not found (Home Manager not activated?)")
    return json.loads(APPS_FILE.read_text())


def load_overrides() -> dict:
    if not OVERRIDES_FILE.is_file():
        return {}
    try:
        return tomllib.loads(OVERRIDES_FILE.read_text())
    except tomllib.TOMLDecodeError as error:
        warn(f"ignoring {OVERRIDES_FILE}: {error}")
        return {}


def _color_variants(digits: str) -> dict[str, str]:
    """The derived forms templates ask for, keyed by the suffix each gets: Qt's
    #AARRGGBB, a bare RRGGBB, GLSL floats, an rgb triple, and a lift toward white."""
    r, g, b = (int(digits[i : i + 2], 16) for i in (0, 2, 4))
    lr, lg, lb = (round(c * 0.8 + 255 * 0.2) for c in (r, g, b))
    return {
        "Argb": "ff" + digits,
        "Hex": digits,
        "Glsl": f"{r / 255:.3f}, {g / 255:.3f}, {b / 255:.3f}",
        "Rgb": f"{r}, {g}, {b}",
        "Light": f"#{lr:02x}{lg:02x}{lb:02x}",
    }


def _luminance(colour: str) -> float:
    """Relative luminance of a #rrggbb colour, 0 for black to 1 for white."""
    r, g, b = (int(colour[i : i + 2], 16) / 255 for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _theme_tokens(data: dict) -> dict[str, str]:
    """Flatten every [section] into one token namespace, expanding colours."""
    tokens: dict[str, str] = {}
    for section in data.values():
        for key, value in section.items():
            value = str(value)
            tokens[key] = value
            hex_match = HEX_RE.match(value)
            if not hex_match:
                continue
            for suffix, derived in _color_variants(hex_match.group(1)).items():
                tokens[key + suffix] = derived
    return tokens


def _validate(name: str, tokens: dict[str, str]) -> None:
    """Reject any value that could carry target syntax into a rendered template."""
    bad = []
    for key in REQUIRED_TOKENS + [k for k in OPTIONAL_TOKENS if k in tokens]:
        value = tokens[key]
        if key in FAMILY_TOKENS:
            if not FAMILY_RE.match(value):
                bad.append(f"{key}: {value!r} is not a font family name")
        elif key in NUMERIC_TOKENS:
            if not value.isdigit():
                bad.append(f"{key}: {value!r} is not a non-negative integer")
        elif not HEX_RE.match(value):
            bad.append(f"{key}: {value!r} is not a #rrggbb colour")
    if bad:
        sys.exit(f"theme-set: theme '{name}' is invalid:\n  " + "\n  ".join(bad))


def load_theme(name: str) -> dict[str, str]:
    theme_file = THEMES_DIR / f"{name}.toml"
    if not theme_file.is_file():
        sys.exit(f"theme-set: unknown theme '{name}' ({theme_file} not found)")
    data = tomllib.loads(theme_file.read_text())
    font_overrides = load_overrides().get("fonts", {})
    if font_overrides:
        data.setdefault("fonts", {}).update(font_overrides)
    tokens = _theme_tokens(data)
    missing = [t for t in REQUIRED_TOKENS if t not in tokens]
    if missing:
        sys.exit(
            f"theme-set: theme '{name}' is missing required keys: {', '.join(missing)}"
        )
    tokens.setdefault("chrome", tokens["mono"])
    _validate(name, tokens)
    tokens["theme"] = name
    tokens["scheme"] = "light" if _luminance(tokens["bg"]) > 0.5 else "dark"
    tokens["sizePt"] = f"{float(tokens['size']) * 3 / 4:g}"
    tokens["sizeSmall"] = str(round(float(tokens["size"]) * 0.9))
    tokens["sizeSmallPt"] = f"{float(tokens['sizeSmall']) * 3 / 4:g}"
    tokens["sizeLarge"] = str(round(float(tokens["size"]) * 1.2))
    tokens["sizeTitle"] = str(round(float(tokens["size"]) * 1.6))
    return tokens


def _weighted_hue_and_saturation(hsv_image) -> tuple[float, float]:
    sample = hsv_image.copy()
    sample.thumbnail((150, 150))
    h_data = sample.getchannel("H").getdata()
    s_data = sample.getchannel("S").getdata()
    v_data = sample.getchannel("V").getdata()
    sin_sum = cos_sum = sat_sum = weight_sum = 0.0
    for h, s, v in zip(h_data, s_data, v_data):
        weight = (s / 255) * (v / 255)
        angle = h / 255 * 2 * math.pi
        sin_sum += math.sin(angle) * weight
        cos_sum += math.cos(angle) * weight
        sat_sum += s
        weight_sum += weight
    hue = (
        (math.atan2(sin_sum, cos_sum) / (2 * math.pi)) % 1.0 if weight_sum > 0 else 0.0
    )
    saturation = (sat_sum / len(h_data)) / 255
    return hue, saturation


def _recolor_image(image, accent_hex: str):
    hsv = image.convert("HSV")
    h, s, v = hsv.split()
    src_hue, src_sat = _weighted_hue_and_saturation(hsv)
    r = int(accent_hex[1:3], 16) / 255
    g = int(accent_hex[3:5], 16) / 255
    b = int(accent_hex[5:7], 16) / 255
    target_hue, target_sat, _ = colorsys.rgb_to_hsv(r, g, b)
    hue_shift = round((target_hue - src_hue) * 256) % 256 if target_sat > 0.05 else 0
    sat_ratio = min(1.6, target_sat / src_sat) if src_sat > 0.02 else 1.0
    lut_h = [(i + hue_shift) % 256 for i in range(256)]
    lut_s = [max(0, min(255, round(i * sat_ratio))) for i in range(256)]
    from PIL import Image

    return Image.merge("HSV", (h.point(lut_h), s.point(lut_s), v)).convert("RGB")


def recolor_wallpaper(theme_name: str, base: Path, accent_hex: str) -> Path | None:
    if not base.is_file():
        warn(f"wallpaper: {base} does not exist")
        return None
    dest = RECOLOR_CACHE_DIR / f"{theme_name}{base.suffix}"
    stamp = dest.with_name(dest.name + ".src")
    key = f"{base}\n{base.stat().st_mtime_ns}\n{accent_hex}\n"
    if dest.is_file() and read_or_empty(stamp) == key:
        return dest
    try:
        from PIL import Image
    except ImportError:
        warn("wallpaper: Pillow not available, cannot recolor")
        return None
    merged = _recolor_image(Image.open(base).convert("RGB"), accent_hex)
    RECOLOR_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    merged.save(dest, compress_level=1)
    write_rendered(stamp, key)
    return dest


def _screen_size() -> tuple[int, int]:
    """The largest output awww reports, or 1920x1080 when it cannot be asked."""
    try:
        out = subprocess.run(
            ["awww", "query"], capture_output=True, text=True, timeout=2, check=True
        ).stdout
    except (subprocess.SubprocessError, OSError):
        return 1920, 1080
    sizes = [(int(w), int(h)) for w, h in re.findall(r": (\d+)x(\d+),", out)]
    return max(sizes, key=lambda s: s[0] * s[1], default=(1920, 1080))


def _mix(a: str, b: str, t: float) -> str:
    pa, pb = ([int(c[i : i + 2], 16) for i in (1, 3, 5)] for c in (a, b))
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(pa, pb))


def _plate_level(path: Path) -> dict | None:
    if path.parent != PLATES_DIR:
        return None
    manifest = tomllib.loads((PLATES_DIR / "plates.toml").read_text())
    return next((lv for lv in manifest["level"] if lv["file"] == path.name), None)


def _plate_colours(tokens: dict[str, str]) -> tuple[str, str]:
    if "plateInk" in tokens and "platePaper" in tokens:
        return tokens["plateInk"], tokens["platePaper"]
    light = tokens["scheme"] == "light"
    tone = _mix(tokens["bg"], tokens["fgMuted"], 0.3 if light else 0.5)
    return (tone, tokens["bg"]) if light else (tokens["bg"], tone)


def _inset_box(size: tuple[int, int], inset) -> tuple[int, int, int, int]:
    pw, ph = size
    left, top, right, bottom = inset or (0, 0, 0, 0)
    w, h = round(pw * (1 - left - right)), round(ph * (1 - top - bottom))
    return w, h, round(pw * left), round(ph * top)


def _desk_crop(plate, low, focus, anchor) -> tuple[int, int, int, int]:
    pw, ph = plate
    lw, lh = low
    k = max(lw / pw, lh / ph)
    sw, sh = math.ceil(pw * k), math.ceil(ph * k)
    ox = round(min(max(focus[0] * sw - anchor[0] * lw, 0), sw - lw))
    oy = round(min(max(focus[1] * sh - anchor[1] * lh, 0), sh - lh))
    return sw, sh, ox, oy


def render_plate(
    theme_name: str, plate: Path, level: dict, tokens: dict[str, str]
) -> Path | None:
    ink, paper = _plate_colours(tokens)
    w, h = _screen_size()
    scale = 3 if h >= 2000 else 2
    lw, lh = math.ceil(w / scale), math.ceil(h / scale)
    dest = PLATE_CACHE_DIR / f"{theme_name}-{plate.stem}.png"
    stamp = dest.with_name(dest.name + ".src")
    key = json.dumps([str(plate), level, ink, paper, w, h], sort_keys=True) + "\n"
    if dest.is_file() and read_or_empty(stamp) == key:
        return dest
    try:
        size = subprocess.run(
            ["magick", "identify", "-format", "%w %h", str(plate)],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        ).stdout.split()
        box = _inset_box((int(size[0]), int(size[1])), level.get("inset"))
        sw, sh, ox, oy = _desk_crop(box[:2], (lw, lh), level["focus"], level["anchor"])
        PLATE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "magick",
                str(plate),
                "-colorspace",
                "gray",
                "-crop",
                f"{box[0]}x{box[1]}+{box[2]}+{box[3]}",
                "+repage",
                "-gamma",
                str(level.get("gamma", 1.0)),
                "-resize",
                f"{sw}x{sh}!",
                "-crop",
                f"{lw}x{lh}+{ox}+{oy}",
                "+repage",
                "-sigmoidal-contrast",
                level["contrast"],
                "-dither",
                "FloydSteinberg",
                "-monochrome",
                "+level-colors",
                f"{ink},{paper}",
                "-filter",
                "point",
                "-resize",
                f"{lw * scale}x{lh * scale}!",
                "-crop",
                f"{w}x{h}+0+0",
                "+repage",
                str(dest),
            ],
            capture_output=True,
            check=True,
            timeout=30,
        )
    except (subprocess.SubprocessError, OSError, ValueError) as error:
        warn(f"plate: {error}")
        return None
    write_rendered(stamp, key)
    return dest


def shown_wallpaper(
    theme_name: str, tokens: dict[str, str], base: Path, recolor: bool
) -> Path | None:
    level = _plate_level(base)
    if level is not None:
        return render_plate(theme_name, base, level, tokens)
    if recolor:
        return recolor_wallpaper(theme_name, base, tokens["accent"])
    return base


def set_wallpaper(path: Path) -> None:
    try:
        subprocess.run(
            [
                "awww",
                "img",
                "-t",
                "fade",
                "--transition-duration",
                "0.5",
                "--transition-fps",
                "60",
                str(path),
            ],
            check=True,
            timeout=5,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        FileNotFoundError,
        OSError,
    ) as error:
        warn(f"wallpaper: awww set failed: {error}")
    try:
        write_rendered(CURRENT_WALLPAPER_FILE, str(path) + "\n")
    except OSError as error:
        warn(f"wallpaper: failed to record current path: {error}")


def render(text: str, tokens: dict[str, str]) -> str:
    for key, value in tokens.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def leftover_tokens(rendered: str) -> list[str]:
    return sorted(set(TOKEN_RE.findall(rendered)))


class ReloadBatch:
    def __init__(self, timeout: float = 5.0):
        self._procs: list[tuple[subprocess.Popen, list[str]]] = []
        self._deadline = time.monotonic() + timeout

    def launch(self, cmd: list[str]) -> None:
        try:
            proc = subprocess.Popen(
                cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        except FileNotFoundError:
            warn(f"'{cmd[0]}' not found")
            return
        except OSError as error:
            warn(f"'{' '.join(cmd)}' failed to start: {error}")
            return
        self._procs.append((proc, cmd))

    def wait(self) -> None:
        for proc, cmd in self._procs:
            try:
                code = proc.wait(timeout=max(0.1, self._deadline - time.monotonic()))
                if code != 0:
                    warn(f"'{' '.join(cmd)}' exited {code}")
            except subprocess.TimeoutExpired:
                proc.kill()
                warn(f"'{' '.join(cmd)}' timed out")


def read_or_empty(path: Path) -> str:
    return path.read_text() if path.is_file() else ""


@contextmanager
def locked(name: str):
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    with open(RUN_DIR / f"{name}.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def write_rendered(dest: Path, rendered: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".tmp")
    tmp.write_text(rendered)
    tmp.replace(dest)


def render_to(source_label: str, text: str, tokens: dict[str, str], dest: Path) -> None:
    rendered = render(text, tokens)
    leftover = leftover_tokens(rendered)
    if leftover:
        warn(f"{source_label}: unreplaced tokens: {', '.join(leftover)}")
    write_rendered(dest, rendered)


def reload_kitty(batch: ReloadBatch, dest: Path) -> None:
    for sock in glob.glob("/tmp/kitty-*"):
        pid = sock.rsplit("-", 1)[-1]
        if pid.isdigit() and not Path(f"/proc/{pid}").is_dir():
            continue
        batch.launch(["kitty", "@", "--to", f"unix:{sock}", "load-config"])
        batch.launch(
            ["kitty", "@", "--to", f"unix:{sock}", "set-colors", "-a", "-c", str(dest)]
        )


def _persisted_wallpaper_pick() -> tuple[Path, bool] | None:
    if not CURRENT_WALLPAPER_SOURCE_FILE.is_file():
        return None
    path = Path(CURRENT_WALLPAPER_SOURCE_FILE.read_text().strip())
    if not path.is_file():
        return None
    recolor = True
    if CURRENT_WALLPAPER_RECOLOR_FILE.is_file():
        recolor = CURRENT_WALLPAPER_RECOLOR_FILE.read_text().strip() != "0"
    return path, recolor


def _render_targets(apps: dict, tokens: dict[str, str]) -> dict[str, Path]:
    """Render every registered template. Returns only what was actually written."""
    dests: dict[str, Path] = {}
    for app_name, app in apps.items():
        template_path = TEMPLATES_DIR / f"{app_name}.tmpl"
        if not template_path.is_file():
            warn(f"{app_name}: template {template_path} missing, skipped")
            continue
        dest = Path(os.path.expanduser(app["target"]))
        render_to(template_path.name, template_path.read_text(), tokens, dest)
        dests[app_name] = dest
    return dests


def _batched(queue):
    def action(name: str) -> None:
        batch = ReloadBatch()
        queue(batch, name)
        batch.wait()

    return action


def _lane_actions(apps: dict, dests: dict[str, Path]) -> dict:
    """One reload per key, each run against whichever theme was rendered last."""
    lanes = {
        "wallpaper": lambda name: _reapply_wallpaper(name, load_theme(name)),
        "desktop-font": _batched(
            lambda b, name: _queue_desktop_font(b, load_theme(name))
        ),
    }
    for app_name, app in apps.items():
        if app_name not in dests:
            continue
        if app_name == "kitty":
            lanes[app_name] = _batched(
                lambda b, _n, d=dests[app_name]: reload_kitty(b, d)
            )
        elif app.get("reload"):
            lanes[app_name] = _batched(lambda b, _n, cmd=app["reload"]: b.launch(cmd))
    return lanes


def _run_lane(key: str, action) -> None:
    with locked(f"lane-{key}"):
        rendered = read_or_empty(RENDERED_FILE)
        done = RUN_DIR / f"lane-{key}.done"
        if not rendered or read_or_empty(done) == rendered:
            return
        action(rendered.split(" ", 1)[1])
        write_rendered(done, rendered)


def copy_sddm_wallpaper(path: Path) -> None:
    if not SDDM_WALLPAPER.parent.is_dir():
        return
    try:
        shutil.copyfile(path, SDDM_WALLPAPER)
    except OSError as error:
        warn(f"sddm wallpaper: {error}")


def _reapply_wallpaper(name: str, tokens: dict[str, str]) -> None:
    """Re-derive the persisted wallpaper pick against the new accent."""
    pick = _persisted_wallpaper_pick()
    if pick is None:
        return
    picked_path, picked_recolor = pick
    path = shown_wallpaper(name, tokens, picked_path, picked_recolor)
    if path is None:
        return
    set_wallpaper(path)
    copy_sddm_wallpaper(path)


def _queue_desktop_font(batch: "ReloadBatch", tokens: dict[str, str]) -> None:
    def gvariant(size) -> str:
        return "'" + f"{tokens['mono']} {size}".replace("'", "\\'") + "'"

    for key, size in (
        ("font-name", tokens["sizeUi"]),
        ("monospace-font-name", tokens["sizePt"]),
    ):
        batch.launch(
            ["dconf", "write", f"/org/gnome/desktop/interface/{key}", gvariant(size)]
        )
    batch.launch(
        [
            "dconf",
            "write",
            "/org/gnome/desktop/interface/color-scheme",
            f"'prefer-{tokens['scheme']}'",
        ]
    )


def request_theme(pick) -> None:
    """Select pick(current), render it at once, then run every reload lane."""
    with locked("select"):
        name = pick(current_theme())
        load_theme(name)
        write_rendered(CURRENT_FILE, name + "\n")
        write_rendered(REQUEST_FILE, f"{time.time_ns()} {name}")
    apps = load_apps()
    with locked("render"):
        request = read_or_empty(REQUEST_FILE)
        if request == read_or_empty(RENDERED_FILE):
            return
        name = request.split(" ", 1)[1]
        dests = _render_targets(apps, load_theme(name))
        write_rendered(RENDERED_FILE, request)
        subprocess.Popen(
            ["notify-send", "-e", "-a", "theme-set", "Theme applied", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    threads = [
        threading.Thread(target=_run_lane, args=lane)
        for lane in _lane_actions(apps, dests).items()
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()


def list_themes() -> list[str]:
    return sorted(p.stem for p in THEMES_DIR.glob("*.toml"))


def current_theme() -> str:
    if CURRENT_FILE.is_file():
        return CURRENT_FILE.read_text().strip()
    return DEFAULT_THEME


def cycle(step: int) -> None:
    names = list_themes()
    if not names:
        sys.exit(f"theme-set: no themes found in {THEMES_DIR}")

    def pick(cur: str) -> str:
        idx = names.index(cur) if cur in names else 0
        return names[(idx + step) % len(names)]

    request_theme(pick)


def font_command(args: list[str]) -> None:
    if not args:
        override = load_overrides().get("fonts", {}).get("mono")
        print(override if override else "(theme default)")
        return
    if args == ["default"]:
        OVERRIDES_FILE.unlink(missing_ok=True)
    else:
        family = " ".join(args)
        if not FAMILY_RE.match(family):
            sys.exit(f"theme-set: {family!r} is not a font family name")
        ENGINE_DIR.mkdir(parents=True, exist_ok=True)
        OVERRIDES_FILE.write_text(f'[fonts]\nmono = "{family}"\n')
    request_theme(lambda cur: cur)


def reset_wallpaper() -> None:
    try:
        write_rendered(CURRENT_WALLPAPER_SOURCE_FILE, "")
        write_rendered(CURRENT_WALLPAPER_RECOLOR_FILE, "")
    except OSError as error:
        warn(f"wallpaper: failed to reset pick: {error}")
    request_theme(lambda cur: cur)


def wallpaper_command(path_str: str, recolor: bool = True) -> None:
    path = Path(os.path.expanduser(path_str))
    if not path.is_file():
        sys.exit(f"theme-set: {path} does not exist")
    name = current_theme()
    shown = shown_wallpaper(name, load_theme(name), path, recolor) or path
    set_wallpaper(shown)
    try:
        write_rendered(CURRENT_WALLPAPER_SOURCE_FILE, str(path) + "\n")
        write_rendered(CURRENT_WALLPAPER_RECOLOR_FILE, "1" if recolor else "0")
    except OSError as error:
        warn(f"wallpaper: failed to record source path: {error}")
    copy_sddm_wallpaper(shown)


PREVIEW_CODE = (
    (("magenta", "def "), ("blue", "greet"), ("fg", "(n):")),
    (("fgMuted", "  # say hello"),),
    (("fg", "  s = "), ("green", '"hey"')),
    (("magenta", "  if "), ("fg", "n > "), ("yellow", "42"), ("fg", ":")),
    (("cyan", "    print"), ("fg", "(s)")),
    (("magenta", "  return "), ("red", "None")),
)
PREVIEW_SWATCHES = (
    ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"),
    (
        "brightBlack",
        "brightRed",
        "brightGreen",
        "brightYellow",
        "brightBlue",
        "brightMagenta",
        "brightCyan",
        "brightWhite",
    ),
    ("accent", "error", "warning", "success", "info"),
    ("bgDim", "bg", "bgAlt", "border", "fgMuted", "fgDim", "fg"),
)


def _preview_font(family: str, size: str):
    from PIL import ImageFont

    path = subprocess.run(
        ["fc-match", "-f", "%{file}", family],
        capture_output=True,
        text=True,
        check=False,
    ).stdout
    try:
        return ImageFont.truetype(path, int(size))
    except OSError:
        return ImageFont.load_default(int(size))


def render_preview(tokens: dict[str, str], width: int, height: int):
    """A card of the theme: its name as a selected menu row, code, and its palette."""
    from PIL import Image, ImageDraw

    pad, gap, swatch = 8, 8, 12
    image = Image.new("RGB", (width, height), tokens["bg"])
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width - 1, height - 1), outline=tokens["border"])

    chrome = _preview_font(tokens["chrome"], tokens["sizeSmall"])
    bar = sum(chrome.getmetrics()) + 4
    draw.rectangle((pad, pad, width - pad - 1, pad + bar - 1), fill=tokens["accent"])
    draw.text(
        (pad + pad // 2, pad + bar / 2),
        tokens["theme"],
        font=chrome,
        fill=tokens["bg"],
        anchor="lm",
    )

    top = height - pad - swatch * len(PREVIEW_SWATCHES)
    term = _preview_font(tokens["chrome"], tokens["size"])
    line = sum(term.getmetrics())
    y = pad + bar + gap
    for segments in PREVIEW_CODE:
        if y + line > top - gap:
            break
        x = pad + pad // 2
        for colour, text in segments:
            draw.text((x, y), text, font=term, fill=tokens[colour])
            x += term.getlength(text)
        y += line

    inner = width - 2 * pad
    for row, keys in enumerate(PREVIEW_SWATCHES):
        y = top + row * swatch
        for i, key in enumerate(keys):
            x0 = pad + i * inner // len(keys)
            x1 = pad + (i + 1) * inner // len(keys)
            draw.rectangle((x0, y, x1 - 1, y + swatch - 1), fill=tokens[key])
    draw.rectangle(
        (pad - 1, top - 1, width - pad, height - pad), outline=tokens["border"]
    )
    return image


def previews_command(args: list[str]) -> None:
    if len(args) != 2 or not args[1].isdigit():
        sys.exit("theme-set: previews requires a directory and a width")
    out = Path(os.path.expanduser(args[0]))
    width = int(args[1])
    height = width * 4 // 3
    out.mkdir(parents=True, exist_ok=True)
    stamp = out / ".stamp"
    key = f"{__file__} {width}x{height}\n"
    fresh = read_or_empty(stamp) == key
    names = list_themes()
    for old in out.iterdir():
        if not old.name.startswith(".") and old.name not in names:
            old.unlink()
    floor = OVERRIDES_FILE.stat().st_mtime if OVERRIDES_FILE.is_file() else 0
    for name in names:
        dest = out / name
        source = (THEMES_DIR / f"{name}.toml").stat().st_mtime
        if fresh and dest.is_file() and dest.stat().st_mtime >= max(source, floor):
            continue
        tmp = out / f".{name}.tmp"
        render_preview(load_theme(name), width, height).save(tmp, "PNG")
        tmp.replace(dest)
    write_rendered(stamp, key)


USAGE = (
    "usage: theme-set <name>|list|current|next|prev|reapply|"
    "font [<family>|default]|wallpaper <path> [--no-recolor]|"
    "wallpaper-reset|previews <dir> <width>"
)


def _cmd_list(_args: list[str]) -> None:
    cur = current_theme()
    for name in list_themes():
        print(("* " if name == cur else "  ") + name)


def _cmd_wallpaper(args: list[str]) -> None:
    if not args:
        sys.exit("theme-set: wallpaper requires a path")
    with locked("lane-wallpaper"):
        wallpaper_command(args[0], recolor="--no-recolor" not in args[1:])


COMMANDS = {
    "list": _cmd_list,
    "current": lambda _a: print(current_theme()),
    "next": lambda _a: cycle(1),
    "prev": lambda _a: cycle(-1),
    "reapply": lambda _a: request_theme(lambda cur: cur),
    "font": font_command,
    "wallpaper": _cmd_wallpaper,
    "wallpaper-reset": lambda _a: reset_wallpaper(),
    "previews": previews_command,
}


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(USAGE)
        return
    COMMANDS.get(args[0], lambda _a: request_theme(lambda _cur: args[0]))(args[1:])


if __name__ == "__main__":
    main()
