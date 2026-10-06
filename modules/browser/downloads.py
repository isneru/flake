import atexit
import json
import os
import sys
import threading
import time
import types

from qutebrowser.utils import objreg

_STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "quickshell",
    "downloads.json",
)

_INTERVAL = 0.5
_DWELL = 1.5

_STORE = sys.modules.setdefault(
    "_notch_downloads", types.ModuleType("_notch_downloads")
)


def _entry(item):
    stats = item.stats
    percent = stats.percentage()
    eta = stats.remaining_time()
    return {
        "name": item.basename,
        "done": stats.done or 0,
        "total": stats.total,
        "percent": None if percent is None else int(percent),
        "speed": 0 if item.done else int(stats.speed),
        "eta": None if eta is None or item.done else int(eta),
    }


def _finished_at(item, previous, now, seeding):
    if previous is not None:
        return previous
    if seeding or not item.successful:
        return float("-inf")
    return now


def _active(seen, now, seeding):
    out = []
    kept = {}
    for name in ("qtnetwork-download-manager", "webengine-download-manager"):
        manager = objreg.get(name, default=None)
        if manager is None:
            continue
        for item in list(manager.downloads):
            key = id(item)
            finished = None
            if item.done:
                previous = seen[key][1] if key in seen else None
                finished = _finished_at(item, previous, now, seeding)
            kept[key] = (item, finished)
            if finished is None or now - finished < _DWELL:
                out.append(_entry(item))
    seen.clear()
    seen.update(kept)
    return out


def _write(payload):
    os.makedirs(os.path.dirname(_STATE), exist_ok=True)
    with open(_STATE, "w") as handle:
        json.dump(payload, handle)
        handle.write("\n")


def _loop(stop):
    last = None
    seen = {}
    seeding = True
    while True:
        try:
            active = _active(seen, time.monotonic(), seeding)
            seeding = False
        except Exception:  # noqa: BLE001 - a bad read must not kill the thread
            active = last["active"] if last else []
        payload = {"active": active, "count": len(active)}
        if payload != last:
            last = payload
            _write(payload)
        if stop.wait(_INTERVAL):
            return


_previous = getattr(_STORE, "stop", None)
if _previous is not None:
    _previous.set()

_STORE.stop = threading.Event()
_STORE.thread = threading.Thread(
    target=_loop,
    args=(_STORE.stop,),
    name="notch-downloads",
    daemon=True,
)
_STORE.thread.start()

if not getattr(_STORE, "atexit_hooked", False):
    atexit.register(lambda: _write({"active": [], "count": 0}))
    _STORE.atexit_hooked = True
