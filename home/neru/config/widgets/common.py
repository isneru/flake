import contextlib
import json
import locale as _locale
import os
import re
import select
import subprocess
import sys
import termios
import urllib.request
from collections import deque
from pathlib import Path
from typing import NamedTuple

with contextlib.suppress(_locale.Error):
    _locale.setlocale(_locale.LC_ALL, "")

from colors import (
    ACCENT,
    BG,
    BG_ALT,
    BG_DIM,
    BLUE,
    BORDER,
    CYAN,
    ERROR,
    FG,
    FG_DIM,
    FG_MUTED,
    INFO,
    ORANGE,
    RED,
    SUCCESS,
    WARNING,
)

DIGITS = {
    "0": ["█▀█", "█▄█"],
    "1": [" ▀█", " ▄█"],
    "2": ["▀▀█", "█▄▄"],
    "3": ["▀▀█", "▄▄█"],
    "4": ["█ █", "▀▀█"],
    "5": ["█▀▀", "▄▄█"],
    "6": ["█▀▀", "█▄█"],
    "7": ["▀▀█", "  █"],
    "8": ["█▀█", "█▀█"],
    "9": ["█▀█", "▄▄█"],
}

COLON_ON = ["▀", "▄"]
COLON_OFF = [" ", " "]


def render_big_time(time_str: str, colon_on: bool = True) -> tuple[str, str]:
    colon = COLON_ON if colon_on else COLON_OFF
    row1, row2 = [], []
    for ch in time_str:
        if ch == ":":
            row1.append(colon[0])
            row2.append(colon[1])
        elif ch in DIGITS:
            row1.append(DIGITS[ch][0])
            row2.append(DIGITS[ch][1])
    return " ".join(row1), " ".join(row2)


def sparkline(values: list[float], width: int = 8) -> str:
    if not values:
        return " " * width
    bars = "▁▂▃▄▅▆▇█"
    mn, mx = min(values), max(values)
    rng = mx - mn if mx != mn else 1.0
    recent = list(values)[-width:]
    return "".join(bars[min(int((v - mn) / rng * 7), 7)] for v in recent)


def progress_bar(pct: float, width: int = 10) -> str:
    filled = int(pct / 100 * width)
    return "█" * filled + "░" * (width - filled)


ICON = {
    "cpu": "\U000f0ee0",
    "ram": "\U000f035b",
    "bat": "\U000f0079",
    "bat_charging": "\U000f0084",
    "vol": "\U000f057e",
    "vol_muted": "\U000f0581",
    "bri": "\U000f00df",
    "wifi": "\U000f05a9",
    "wifi_off": "\U000f05aa",
    "bt": "\U000f00af",
    "bt_off": "\U000f00b2",
    "bell": "\U000f009a",
    "calendar": "\U000f00ed",
    "kbd": "\U000f030c",
    "pos": "\U000f0299",
    "zoom": "\U000f0751",
    "caffeine": "\U000f0176",
    "caffeine_off": "\U000f0177",
    "power": "\U000f0425",
}

WEATHER_ICON = {
    "Clear": "☀",
    "Partly cloudy": "⛅",
    "Overcast": "☁",
    "Fog": "\U0001f32b",
    "Drizzle": "\U0001f326",
    "Rain": "\U0001f327",
    "Snow": "❄",
    "Thunderstorm": "⚡",
}

_WMO_DESC = {
    0: "Clear",
    1: "Clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Fog",
    51: "Drizzle",
    53: "Drizzle",
    55: "Drizzle",
    56: "Drizzle",
    57: "Drizzle",
    61: "Rain",
    63: "Rain",
    65: "Rain",
    66: "Rain",
    67: "Rain",
    71: "Snow",
    73: "Snow",
    75: "Snow",
    77: "Snow",
    80: "Rain",
    81: "Rain",
    82: "Rain",
    85: "Snow",
    86: "Snow",
    95: "Thunderstorm",
    96: "Thunderstorm",
    99: "Thunderstorm",
}


def weather_icon(desc: str) -> str:
    return WEATHER_ICON.get(desc, "☁")


class CpuTracker:
    def __init__(self):
        self._prev = self._read()
        self.history: deque[float] = deque(maxlen=20)

    @staticmethod
    def _read():
        with open("/proc/stat") as f:
            parts = f.readline().split()[1:]
        vals = [int(x) for x in parts]
        idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
        total = sum(vals)
        return idle, total

    def percent(self) -> float:
        idle, total = self._read()
        di = idle - self._prev[0]
        dt = total - self._prev[1]
        self._prev = (idle, total)
        pct = 100.0 * (1 - di / dt) if dt else 0.0
        self.history.append(pct)
        return pct


def get_cpu_percent(tracker: CpuTracker) -> float:
    return tracker.percent()


class MemInfo(NamedTuple):
    total_mb: int
    used_mb: int
    percent: float


def get_memory() -> MemInfo:
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 2:
                info[parts[0].rstrip(":")] = int(parts[1])
    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable", 0)
    used = total - avail
    pct = 100.0 * used / total if total else 0.0
    return MemInfo(total // 1024, used // 1024, pct)


def get_battery() -> tuple[int, bool] | None:
    for bat in sorted(Path("/sys/class/power_supply").glob("BAT*")):
        try:
            cap = int((bat / "capacity").read_text().strip())
            status = (bat / "status").read_text().strip()
            return cap, status == "Charging"
        except (OSError, ValueError):
            continue
    return None


def battery_icon(pct: int, charging: bool) -> str:
    if charging:
        return ICON["bat_charging"]
    return ICON["bat"]


def get_volume() -> tuple[int, bool]:
    try:
        out = subprocess.check_output(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            text=True,
            timeout=2,
        ).strip()
        muted = "[MUTED]" in out
        match = re.search(r"(\d+\.\d+)", out)
        vol = int(float(match.group(1)) * 100) if match else 0
        return vol, muted
    except (subprocess.SubprocessError, OSError):
        return 0, False


def volume_icon(muted: bool) -> str:
    return ICON["vol_muted"] if muted else ICON["vol"]


def get_wifi() -> str | None:
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"],
            text=True,
            timeout=2,
        )
        for line in out.strip().split("\n"):
            if line.startswith("yes:"):
                return line.split(":", 1)[1]
    except (subprocess.SubprocessError, OSError):
        pass
    return None


def wifi_icon(connected: bool) -> str:
    return ICON["wifi"] if connected else ICON["wifi_off"]


def get_bluetooth() -> bool:
    try:
        out = subprocess.check_output(
            ["bluetoothctl", "show"],
            text=True,
            timeout=2,
        )
        for line in out.strip().split("\n"):
            if "Powered:" in line:
                return "yes" in line
    except (subprocess.SubprocessError, OSError, FileNotFoundError):
        pass
    return False


def get_notifications() -> int:
    try:
        out = subprocess.check_output(
            ["swaync-client", "-c"],
            text=True,
            timeout=2,
        ).strip()
        return int(out)
    except (subprocess.SubprocessError, OSError, ValueError):
        return 0


def get_brightness() -> int:
    try:
        out = subprocess.check_output(
            ["brightnessctl", "-m"],
            text=True,
            timeout=2,
        ).strip()
        parts = out.split(",")
        if len(parts) >= 4:
            return int(parts[3].rstrip("%"))
    except (subprocess.SubprocessError, OSError, ValueError):
        pass
    return 100


def brightness_icon() -> str:
    return ICON["bri"]


def _geolocate() -> tuple[float, float, str] | None:
    try:
        req = urllib.request.Request(
            "https://ipapi.co/json/",
            headers={"User-Agent": "driftwm-widget/1.0"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
        return data["latitude"], data["longitude"], data.get("city", "")
    except Exception:
        return None


_geo_cache: tuple[float, float, str] | None = None


def get_weather() -> dict | None:
    global _geo_cache
    if _geo_cache is None:
        _geo_cache = _geolocate()
    if _geo_cache is None:
        return None
    lat, lon, city = _geo_cache
    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast?"
            f"latitude={lat}&longitude={lon}"
            f"&current=temperature_2m,weather_code"
            f"&daily=temperature_2m_max,temperature_2m_min"
            f"&timezone=auto&forecast_days=2"
        )
        req = urllib.request.Request(url, headers={"User-Agent": "driftwm-widget/1.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
        current = data["current"]
        daily = data["daily"]
        code = current["weather_code"]
        return {
            "temp": f"{current['temperature_2m']:.0f}",
            "desc": _WMO_DESC.get(code, "Clear"),
            "high": f"{daily['temperature_2m_max'][0]:.0f}",
            "low": f"{daily['temperature_2m_min'][0]:.0f}",
            "tomorrow_temp": f"{daily['temperature_2m_max'][1]:.0f}",
            "location": city,
        }
    except Exception:
        return None


def read_state_file() -> dict:
    try:
        out = subprocess.check_output(
            ["driftwm", "msg", "state", "--json"],
            text=True,
            timeout=2,
        )
        data = json.loads(out)
        state = data.get("Ok", {}).get("State", data)
        camera = state.get("camera", [])
        if isinstance(camera, list) and len(camera) >= 2:
            state["camera_x"] = int(camera[0])
            state["camera_y"] = int(camera[1])
        return state
    except (subprocess.SubprocessError, OSError, json.JSONDecodeError):
        return {}


def synchronize_live(live) -> None:
    live.update(live.renderable)


def enable_mouse(stdin=None, stdout=None):
    out = stdout or sys.stdout
    out.write("\033[?1000h\033[?1002h")
    if hasattr(out, "flush"):
        out.flush()


def disable_mouse(stdin=None, stdout=None):
    out = stdout or sys.stdout
    try:
        out.write("\033[?1002l\033[?1000l")
        if hasattr(out, "flush"):
            out.flush()
    except (BrokenPipeError, OSError):
        pass


def poll_click(timeout: float, stdin=None) -> tuple[int, int] | None:
    fd = (stdin or sys.stdin.buffer).fileno()
    ready, _, _ = select.select([fd], [], [], timeout)
    if not ready:
        return None
    data = os.read(fd, 64)
    idx = data.find(b"\033[M")
    if idx < 0 or idx + 5 >= len(data):
        return None
    btn = data[idx + 3] - 32
    if btn & 0x20:
        return None
    if btn & 3 == 3:
        return None
    x = data[idx + 4] - 32
    y = data[idx + 5] - 32
    return (x, y)
