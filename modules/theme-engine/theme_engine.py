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
RECOLOR_CACHE_DIR = CACHE_HOME / "theme-engine" / "wallpapers-recolored"
WALLPAPER_PREVIEW_CACHE_DIR = CACHE_HOME / "theme-engine" / "wallpaper-previews"
WALLPAPER_PREVIEW_MAX_DIM = 400
WALLPAPER_EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp")
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
    for key in REQUIRED_TOKENS:
        value = tokens[key]
        if key == "mono":
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


def generate_wallpaper_previews(folder: Path) -> None:
    try:
        from PIL import Image
    except ImportError:
        warn("wallpaper preview: Pillow not available, cannot recolor")
        return
    if not folder.is_dir():
        return
    name = current_theme()
    tokens = load_theme(name)
    accent = tokens["accent"]
    dest_dir = WALLPAPER_PREVIEW_CACHE_DIR / name
    dest_dir.mkdir(parents=True, exist_ok=True)
    for src in folder.iterdir():
        if not src.is_file() or src.suffix.lower() not in WALLPAPER_EXTENSIONS:
            continue
        dest = dest_dir / src.name
        if dest.is_file() and dest.stat().st_mtime >= src.stat().st_mtime:
            continue
        try:
            image = Image.open(src).convert("RGB")
            image.thumbnail((WALLPAPER_PREVIEW_MAX_DIM, WALLPAPER_PREVIEW_MAX_DIM))
            tmp = dest.with_name(f".{dest.stem}.tmp{dest.suffix}")
            _recolor_image(image, accent).save(tmp, compress_level=1)
            tmp.replace(dest)
        except OSError as error:
            warn(f"wallpaper preview: {src.name}: {error}")


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
    path = (
        recolor_wallpaper(name, picked_path, tokens["accent"])
        if picked_recolor
        else picked_path
    )
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
    tokens = load_theme(name)
    recolored = recolor_wallpaper(name, path, tokens["accent"]) if recolor else None
    set_wallpaper(recolored if recolored is not None else path)
    try:
        write_rendered(CURRENT_WALLPAPER_SOURCE_FILE, str(path) + "\n")
        write_rendered(CURRENT_WALLPAPER_RECOLOR_FILE, "1" if recolor else "0")
    except OSError as error:
        warn(f"wallpaper: failed to record source path: {error}")
    copy_sddm_wallpaper(recolored if recolored is not None else path)


USAGE = (
    "usage: theme-set <name>|list|current|next|prev|reapply|"
    "font [<family>|default]|wallpaper <path> [--no-recolor]|"
    "wallpaper-reset|wallpaper-previews <folder>|palettes"
)


def _cmd_list(_args: list[str]) -> None:
    cur = current_theme()
    for name in list_themes():
        print(("* " if name == cur else "  ") + name)


def _cmd_palettes(_args: list[str]) -> None:
    font_overrides = load_overrides().get("fonts", {})
    out: dict[str, dict] = {}
    for path in sorted(THEMES_DIR.glob("*.toml")):
        try:
            data = tomllib.loads(path.read_text())
        except (OSError, tomllib.TOMLDecodeError) as error:
            warn(f"palettes: skipping {path.name}: {error}")
            continue
        fonts = {**data.get("fonts", {}), **font_overrides}
        out[path.stem] = {**data.get("colors", {}), "mono": str(fonts.get("mono", ""))}
    print(json.dumps(out))


def _cmd_wallpaper(args: list[str]) -> None:
    if not args:
        sys.exit("theme-set: wallpaper requires a path")
    with locked("lane-wallpaper"):
        wallpaper_command(args[0], recolor="--no-recolor" not in args[1:])


def _cmd_previews(args: list[str]) -> None:
    if not args:
        sys.exit("theme-set: wallpaper-previews requires a folder")
    generate_wallpaper_previews(Path(os.path.expanduser(args[0])))


COMMANDS = {
    "list": _cmd_list,
    "current": lambda _a: print(current_theme()),
    "next": lambda _a: cycle(1),
    "prev": lambda _a: cycle(-1),
    "reapply": lambda _a: request_theme(lambda cur: cur),
    "font": font_command,
    "wallpaper": _cmd_wallpaper,
    "wallpaper-reset": lambda _a: reset_wallpaper(),
    "wallpaper-previews": _cmd_previews,
    "palettes": _cmd_palettes,
}


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(USAGE)
        return
    COMMANDS.get(args[0], lambda _a: request_theme(lambda _cur: args[0]))(args[1:])


if __name__ == "__main__":
    main()
