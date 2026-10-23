import io
import os
import re
import subprocess
import sys
import tarfile
from pathlib import Path

from PIL import Image, ImageOps

HOME = Path.home()
WALLS = HOME / "pictures" / "wallpapers"
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share"))
PLATES = DATA / "theme-engine" / "plates"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "phone-walls"
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state"))
SOURCE = STATE / "quickshell" / "wallpaper-source"
SIZE = (180, 390)
SESSION = ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "DISPLAY")
SAFE = re.compile(r"[A-Za-z0-9._+-]+")


def choices() -> dict[str, Path]:
    """Map each phone-safe id to its wallpaper, in the desktop picker's order."""
    found = {}
    if WALLS.is_dir():
        found |= {p.name: p for p in sorted(WALLS.iterdir()) if p.is_file()}
    found |= {f"plates+{p.name}": p for p in sorted(PLATES.glob("*.jpg"))}
    return {key: path for key, path in found.items() if SAFE.fullmatch(key)}


def thumb(key: str, path: Path) -> bytes:
    """Return the phone-shaped thumbnail of one wallpaper, rebuilding it if stale."""
    dest = CACHE / key
    if not dest.is_file() or dest.stat().st_mtime < path.stat().st_mtime:
        CACHE.mkdir(parents=True, exist_ok=True)
        tmp = CACHE / f".{key}.tmp"
        with Image.open(path) as image:
            ImageOps.fit(image.convert("RGB"), SIZE).save(tmp, "JPEG", quality=80)
        tmp.replace(dest)
    return dest.read_bytes()


def add(tar: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    tar.addfile(info, io.BytesIO(data))


def listing(have: set[str]) -> None:
    walls = choices()
    current = Path(SOURCE.read_text().strip()) if SOURCE.is_file() else None
    picked = next(
        (k for k, p in walls.items() if current and p.resolve() == current.resolve()),
        "",
    )
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|") as tar:
        add(tar, "list", "\n".join(walls).encode())
        add(tar, "current", picked.encode())
        for key, path in walls.items():
            if key not in have:
                add(tar, f"t/{key}", thumb(key, path))


def pick(key: str) -> None:
    path = choices().get(key)
    if path is None:
        sys.exit(f"phone-walls: no wallpaper {key}")
    shown = subprocess.run(
        ["systemctl", "--user", "show-environment"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout
    env = dict(os.environ)
    for line in shown.splitlines():
        name, _, value = line.partition("=")
        if name in SESSION:
            env[name] = value
    os.execvpe("neru", ["neru", "theme", "wallpaper", str(path)], env)


def main() -> None:
    args = sys.argv[1:]
    if args[:1] == ["list"]:
        listing(set(args[1:]))
    elif len(args) == 2 and args[0] == "set":
        pick(args[1])
    else:
        sys.exit("usage: neru phone walls list [<id>...]|set <id>")


if __name__ == "__main__":
    main()
