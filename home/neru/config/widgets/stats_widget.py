import contextlib
import subprocess
import sys
from collections import deque

from common import (
    ICON,
    CpuTracker,
    battery_icon,
    brightness_icon,
    disable_mouse,
    enable_mouse,
    get_battery,
    get_bluetooth,
    get_brightness,
    get_volume,
    get_wifi,
    poll_click,
    progress_bar,
    sparkline,
    synchronize_live,
    volume_icon,
    wifi_icon,
)
from rich.console import Console
from rich.live import Live
from rich.text import Text

WIDTH = 38
HEIGHT = 12

cpu_tracker = CpuTracker()
mem_history: deque[float] = deque(maxlen=20)


def _swayidle_active() -> bool:
    return (
        subprocess.run(
            ["systemctl", "--user", "is-active", "--quiet", "swayidle.service"],
            check=False,
        ).returncode
        == 0
    )


def _toggle_caffeine():
    if _swayidle_active():
        subprocess.run(
            ["systemctl", "--user", "stop", "swayidle.service"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    else:
        subprocess.run(
            ["systemctl", "--user", "start", "swayidle.service"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def render(height: int) -> Text:
    text = Text()
    top_pad = max((height - 10) // 2, 0)
    text.append("\n" * top_pad)

    cpu_pct = get_cpu_percent_tracked()
    from common import get_memory

    mem = get_memory()
    mem_history.append(mem.percent)

    cpu_spark = sparkline(list(cpu_tracker.history), 8)
    mem_spark = sparkline(list(mem_history), 8)

    text.append(f" {ICON['cpu']} ", style="cyan")
    text.append(f"cpu {cpu_pct:5.1f}%  {cpu_spark}\n")
    text.append(f" {ICON['ram']} ", style="green")
    text.append(f"ram {mem.percent:5.1f}%  {mem_spark}\n")

    text.append("\n")

    bat = get_battery()
    if bat is not None:
        pct, charging = bat
        icon = battery_icon(pct, charging)
        bar = progress_bar(pct, 10)
        status = "+" if charging else ""
        text.append(f" {icon} ", style="yellow")
        label = f"{pct:3d}%{status}"
        text.append(f"bat {label:<5s} {bar}\n")
    else:
        text.append("\n")

    vol, muted = get_volume()
    vi = volume_icon(muted)
    vol_bar = progress_bar(vol, 10)
    text.append(f" {vi} ", style="magenta")
    text.append(f"vol {vol:3d}%  {vol_bar}\n")

    bri = get_brightness()
    bi = brightness_icon()
    bri_bar = progress_bar(bri, 10)
    text.append(f" {bi} ", style="yellow")
    text.append(f"bri {bri:3d}%  {bri_bar}\n")

    text.append("\n")

    ssid = get_wifi()
    wi = wifi_icon(ssid is not None)
    wifi_text = ssid if ssid else "offline"
    text.append(f" {wi} ", style="blue")
    text.append(f"{wifi_text}\n")

    bt = get_bluetooth()
    bt_icon = ICON["bt"] if bt else ICON["bt_off"]
    bt_text = "on" if bt else "off"
    text.append(f" {bt_icon} ", style="blue")
    text.append(f"bt {bt_text}\n")

    caffeine = not _swayidle_active()
    caff_icon = ICON["caffeine"] if caffeine else ICON["caffeine_off"]
    caff_text = "idle off" if caffeine else "idle on"
    text.append(f" {caff_icon} ", style="red" if caffeine else "dim")
    text.append(f"{caff_text}\n")

    return text


def get_cpu_percent_tracked() -> float:
    return cpu_tracker.percent()


def _content_row(y: int, height: int) -> int:
    top_pad = max((height - 10) // 2, 0)
    return y - top_pad


def run(stdin, stdout, width: int, height: int) -> None:
    console = Console(
        file=stdout,
        width=width,
        highlight=False,
        force_terminal=True,
        color_system="truecolor",
    )
    enable_mouse(stdin=stdin, stdout=stdout)
    try:
        with Live(render(height), console=console, refresh_per_second=1) as live:
            synchronize_live(live)
            while True:
                live.update(render(height))
                click = poll_click(1.0, stdin=stdin)
                if click is not None:
                    _, y = click
                    row = _content_row(y, height)
                    if row == 10:
                        _toggle_caffeine()
    except (BrokenPipeError, ConnectionResetError, OSError):
        pass
    finally:
        disable_mouse(stdin=stdin, stdout=stdout)


if __name__ == "__main__":
    run(sys.stdin.buffer, sys.stdout, WIDTH, HEIGHT)
