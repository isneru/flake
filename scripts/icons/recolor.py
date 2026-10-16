import argparse
import json
import os
import re
import shutil
from pathlib import Path

BLUE = re.compile(r"(folder|user)-blue(-.+)?\.svg")
SHADES = {"#5294e2": 1.0, "#4877b1": 0.8, "#1d344f": 0.35}
PALETTE = re.compile("|".join(SHADES))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="icons-recolor")
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("manifest", "build"):
        sub = commands.add_parser(command)
        sub.add_argument("--root", type=Path, required=True)
        sub.add_argument("--theme", required=True)
    build = commands.choices["build"]
    build.add_argument("--manifest", type=Path, required=True)
    build.add_argument("--colors", type=Path, required=True)
    build.add_argument("--icons", type=Path, required=True)
    build.add_argument("--name", required=True)
    build.add_argument("--light-theme", required=True)
    return parser.parse_args()


def manifest(root: Path, theme: str) -> dict[str, list[str]]:
    base = root / theme
    sources: dict[str, list[str]] = {}
    for dirpath, _, files in os.walk(base, followlinks=True):
        for file in files:
            path = Path(dirpath, file)
            real = path.resolve()
            if BLUE.fullmatch(real.name):
                sources.setdefault(str(real.relative_to(root)), []).append(
                    str(path.relative_to(base))
                )
    return {source: sorted(dests) for source, dests in sorted(sources.items())}


def shade(color: str, factor: float) -> str:
    rgb = (int(color[i : i + 2], 16) for i in (1, 3, 5))
    return "#" + "".join(f"{round(c * factor):02x}" for c in rgb)


def build(args: argparse.Namespace, folder: str, inherits: str, out: Path) -> None:
    shades = {source: shade(folder, factor) for source, factor in SHADES.items()}
    for source, dests in json.loads(args.manifest.read_text()).items():
        svg = PALETTE.sub(lambda m: shades[m[0]], (args.root / source).read_text())
        for dest in dests:
            path = out / dest
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(svg)
    index = (args.root / args.theme / "index.theme").read_text()
    index = re.sub(
        r"^Name=.*$", f"Name={args.name}", index, count=1, flags=re.MULTILINE
    )
    index = re.sub(
        r"^Inherits=.*$", f"Inherits={inherits}", index, count=1, flags=re.MULTILINE
    )
    (out / "index.theme").write_text(index)


def install(icons: Path, name: str, staging: Path) -> None:
    link = icons / name
    current = os.readlink(link) if link.is_symlink() else None
    slot = icons / (f"{name}-b" if current == f"{name}-a" else f"{name}-a")
    shutil.rmtree(slot, ignore_errors=True)
    staging.rename(slot)
    if link.exists():
        stamp = max(slot.stat().st_mtime, link.stat().st_mtime + 1)
        os.utime(slot, (stamp, stamp))
    temp = icons / f".{name}.link"
    temp.unlink(missing_ok=True)
    temp.symlink_to(slot.name)
    os.replace(temp, link)


def main() -> None:
    args = parse_args()
    if args.command == "manifest":
        print(json.dumps(manifest(args.root, args.theme)))
        return
    colors = json.loads(args.colors.read_text())
    inherits = args.light_theme if colors["scheme"] == "light" else args.theme
    staging = args.colors.with_name("icons-build")
    shutil.rmtree(staging, ignore_errors=True)
    build(args, colors["folder"], inherits, staging)
    args.icons.mkdir(parents=True, exist_ok=True)
    install(args.icons, args.name, staging)


if __name__ == "__main__":
    main()
