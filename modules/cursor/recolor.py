import argparse
import json
import os
import shutil
import subprocess
import time
import tomllib
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

CANVAS = 256
ROLES = {"#00FF00": "fill", "#0000FF": "outline", "#FF0000": "fill"}
SCALES = (1, 1.5, 2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="cursor-recolor")
    parser.add_argument("--svgs", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--colors", type=Path, required=True)
    parser.add_argument("--icons", type=Path, required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--inherits", required=True)
    parser.add_argument("--size", type=int, required=True)
    return parser.parse_args()


def recolor(svg: str, colors: dict[str, str]) -> str:
    for placeholder, role in ROLES.items():
        svg = svg.replace(placeholder, colors[role])
    return svg


def frames(svgs: Path, png: str) -> list[Path]:
    stem = png.removesuffix(".png")
    if stem.endswith("-*"):
        base = stem.removesuffix("-*")
        return sorted((svgs / base).glob(f"{base}-*.svg"))
    return [svgs / f"{stem}.svg"]


def hotspot(cursor: dict, fallback: dict) -> tuple[float, float]:
    x = cursor.get("x_hotspot", fallback["x_hotspot"]) / CANVAS
    y = cursor.get("y_hotspot", fallback["y_hotspot"]) / CANVAS
    return x, y


def meta(cursor: dict, fallback: dict, names: list[str]) -> str:
    x, y = hotspot(cursor, fallback)
    lines = [
        "resize_algorithm = bilinear",
        f"hotspot_x = {x:.4f}",
        f"hotspot_y = {y:.4f}",
        "nominal_size = 1.0",
    ]
    lines += [f"define_override = {alias}" for alias in cursor.get("x11_symlinks", [])]
    if len(names) == 1:
        lines.append(f"define_size = 0, {names[0]}")
    else:
        delay = fallback["x11_delay"]
        lines += [f"define_size = 0, {name}, {delay}" for name in names]
    return "\n".join(lines) + "\n"


def write_hyprcursor(out: Path, cursor: dict, fallback: dict, sources: dict) -> None:
    with zipfile.ZipFile(out / "hyprcursors" / f"{cursor['x11_name']}.hlc", "w") as hlc:
        for name, svg in sources.items():
            hlc.writestr(name, svg)
        hlc.writestr("meta.hl", meta(cursor, fallback, list(sources)))


def render(svg: str, size: int, png: Path) -> None:
    subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(png)],
        input=svg.encode(),
        check=True,
    )


def write_xcursor(
    out: Path, cursor: dict, fallback: dict, names: list[str], sizes: list[int]
) -> None:
    x, y = hotspot(cursor, fallback)
    delay = f" {fallback['x11_delay']}" if len(names) > 1 else ""
    pngs = out / "png"
    config = pngs / f"{cursor['x11_name']}.cfg"
    config.write_text(
        "".join(
            f"{size} {int(x * size)} {int(y * size)} {size}-{Path(name).stem}.png{delay}\n"
            for size in sizes
            for name in names
        )
    )
    cursors = out / "cursors"
    subprocess.run(
        ["xcursorgen", "-p", str(pngs), str(config), str(cursors / cursor["x11_name"])],
        check=True,
    )
    for alias in cursor.get("x11_symlinks", []):
        (cursors / alias).symlink_to(cursor["x11_name"])


def build(
    args: argparse.Namespace, colors: dict[str, str], out: Path, slot: str
) -> None:
    cursors = tomllib.loads(args.config.read_text())["cursors"]
    fallback = cursors.pop("fallback_settings")
    sizes = sorted({round(args.size * scale) for scale in SCALES})
    for sub in ("hyprcursors", "cursors", "png"):
        (out / sub).mkdir(parents=True)
    shapes = []
    for cursor in cursors.values():
        sources = {
            f.name: recolor(f.read_text(), colors)
            for f in frames(args.svgs, cursor["png"])
        }
        write_hyprcursor(out, cursor, fallback, sources)
        shapes.append((cursor, sources))
    jobs = [
        (svg, size, out / "png" / f"{size}-{Path(name).stem}.png")
        for _, sources in shapes
        for name, svg in sources.items()
        for size in sizes
    ]
    with ThreadPoolExecutor(os.cpu_count()) as pool:
        list(pool.map(lambda job: render(*job), jobs))
        list(
            pool.map(
                lambda s: write_xcursor(out, s[0], fallback, list(s[1]), sizes), shapes
            )
        )
    shutil.rmtree(out / "png")
    (out / "manifest.hl").write_text(
        f"name = {slot}\n"
        f"description = Bibata Modern recoloured by theme-engine\n"
        f"version = 1\n"
        f"cursors_directory = hyprcursors\n"
    )
    (out / "index.theme").write_text(
        f"[Icon Theme]\nName={slot}\nInherits={args.inherits}\n"
    )


def next_slot(args: argparse.Namespace) -> str:
    link = args.icons / args.name
    current = os.readlink(link) if link.is_symlink() else None
    return f"{args.name}-b" if current == f"{args.name}-a" else f"{args.name}-a"


def install(args: argparse.Namespace, staging: Path, slot: str) -> None:
    shutil.rmtree(args.icons / slot, ignore_errors=True)
    staging.rename(args.icons / slot)
    link = args.icons / args.name
    temp = args.icons / f".{args.name}.link"
    temp.unlink(missing_ok=True)
    temp.symlink_to(slot)
    if link.is_dir() and not link.is_symlink():
        shutil.rmtree(link)
    os.replace(temp, link)


def set_invisible(value: str) -> None:
    subprocess.run(
        ["hyprctl", "eval", f"hl.config({{ cursor = {{ invisible = {value} }} }})"],
        stdout=subprocess.DEVNULL,
        check=False,
    )


def apply(slot: str, size: int) -> None:
    subprocess.run(
        ["dconf", "write", "/org/gnome/desktop/interface/cursor-theme", f"'{slot}'"],
        check=False,
    )
    if not shutil.which("hyprctl"):
        return
    subprocess.run(
        ["hyprctl", "setcursor", slot, str(size)],
        stdout=subprocess.DEVNULL,
        check=False,
    )
    try:
        set_invisible("true")
        time.sleep(0.6)
    finally:
        set_invisible("false")


def main() -> None:
    args = parse_args()
    colors = json.loads(args.colors.read_text())
    slot = next_slot(args)
    staging = args.colors.with_name("cursor-build")
    shutil.rmtree(staging, ignore_errors=True)
    build(args, colors, staging, slot)
    args.icons.mkdir(parents=True, exist_ok=True)
    install(args, staging, slot)
    apply(slot, args.size)


if __name__ == "__main__":
    main()
