import sys

from common import ICON, disable_mouse, enable_mouse, poll_click, read_state_file, synchronize_live
from rich.console import Console
from rich.live import Live
from rich.text import Text

WIDTH = 38
HEIGHT = 5


def render(height: int) -> Text:
    text = Text()
    top_pad = max((height - 2) // 2, 0)
    text.append("\n" * top_pad)

    state = read_state_file()
    x = state.get("camera_x", "--")
    y = state.get("camera_y", "--")
    raw_zoom = state.get("zoom")
    zoom = f"{raw_zoom * 100:.0f}%" if raw_zoom is not None else "--"

    text.append(f"   {ICON['pos']}  ", style="cyan")
    text.append(f"x: {x}  y: {y}\n")
    text.append(f"   {ICON['zoom']}  ", style="yellow")
    text.append(f"zoom: {zoom}\n")

    return text


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
        with Live(render(height), console=console, refresh_per_second=2) as live:
            synchronize_live(live)
            while True:
                live.update(render(height))
                poll_click(1.0, stdin=stdin)
    except (BrokenPipeError, ConnectionResetError, OSError):
        pass
    finally:
        disable_mouse(stdin=stdin, stdout=stdout)


if __name__ == "__main__":
    run(sys.stdin.buffer, sys.stdout, WIDTH, HEIGHT)
