import atexit
import functools
import json
import os
import types

from qutebrowser.keyinput import modeman
from qutebrowser.mainwindow.statusbar import bar, progress, textbase
from qutebrowser.misc import ipc
from qutebrowser.qt.core import QTimer
from qutebrowser.qt.widgets import QApplication
from qutebrowser.utils import objreg, usertypes

_STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "quickshell",
    "qute.json",
)

_STORE = getattr(bar.StatusBar, "_notch_store", None)
if _STORE is None:
    _STORE = types.SimpleNamespace(pending=False, last=None)
    bar.StatusBar._notch_store = _STORE


def _write(payload):
    os.makedirs(os.path.dirname(_STATE), exist_ok=True)
    with open(_STATE, "w") as handle:
        json.dump(payload, handle)
        handle.write("\n")


def _snapshot():
    try:
        window = objreg.last_focused_window()
    except objreg.NoWindow:
        return {"running": False}
    status = window.status
    tabs = window.tabbed_browser.widget
    tab = tabs.currentWidget()
    history = status.backforward.text()
    match = tab.search.match if tab is not None else None
    scroll = tab.scroller.pos_perc()[1] if tab is not None else None
    return {
        "running": True,
        "socket": ipc.server._socketname if ipc.server is not None else "",
        "private": bool(window.is_private),
        "mode": modeman.instance(window.win_id).mode.name,
        "selection": status._color_flags.caret == bar.ColorFlags.CaretMode.selection,
        "keys": status.keystring.text(),
        "url": status.url.text(),
        "urlType": status.url.urltype,
        "scroll": scroll,
        "back": "<" in history,
        "forward": ">" in history,
        "tab": tabs.currentIndex() + 1,
        "tabs": tabs.count(),
        "match": [match.current, match.total]
        if match and not match.is_null()
        else None,
        "loading": tab is not None
        and tab.load_status() == usertypes.LoadStatus.loading,
        "progress": status.prog.value(),
    }


def _flush():
    _STORE.pending = False
    try:
        payload = _snapshot()
    except Exception:  # noqa: BLE001 - a raise here would reach qutebrowser's crash handler
        return
    if payload != _STORE.last:
        _STORE.last = payload
        _write(payload)


def _changed():
    if _STORE.pending:
        return
    _STORE.pending = True
    QTimer.singleShot(0, _flush)


def _notify():
    try:
        _STORE.changed()
    except Exception:  # noqa: BLE001 - never break the slot we are riding on
        pass


def _hook(cls, name):
    original = getattr(cls, name)

    @functools.wraps(original)
    def wrapper(self, *args):
        result = original(self, *args)
        _notify()
        return result

    setattr(cls, name, wrapper)


def _hook_init():
    original = bar.StatusBar.__init__

    def wrapper(self, *args, **kwargs):
        original(self, *args, **kwargs)
        if not getattr(_STORE, "focus_hooked", False):
            QApplication.instance().focusChanged.connect(lambda *_: _notify())
            _STORE.focus_hooked = True
        _notify()

    bar.StatusBar.__init__ = wrapper


_STORE.changed = _changed

if not getattr(_STORE, "hooked", False):
    _hook(textbase.TextBase, "setText")
    _hook(progress.Progress, "setValue")
    _hook(bar.StatusBar, "on_mode_entered")
    _hook(bar.StatusBar, "on_mode_left")
    _hook_init()
    atexit.register(lambda: _write({"running": False}))
    _STORE.hooked = True
