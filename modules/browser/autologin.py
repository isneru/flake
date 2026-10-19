import contextlib
import functools
import json
import time
import types

from qutebrowser.browser import browsertab
from qutebrowser.qt.core import QProcess
from qutebrowser.utils import message

_FORMS = {
    "moodle.isep.ipp.pt": (
        "form[action$='login/index.php'] input[name=username]",
        "form[action$='login/index.php'] input[name=password]",
        "form[action$='login/index.php'] input[type=submit]",
    ),
    "portal.isep.ipp.pt": (
        "#ContentPlaceHolderMain_txtLoginISEP",
        "#ContentPlaceHolderMain_txtPasswordISEP",
        "#ContentPlaceHolderMain_btLoginISEP",
    ),
}
_RETRY = 60

_FILL = """(() => {
  const [user, password, submit] = %s.map((s) => document.querySelector(s));
  if (!user || !password || !submit) return;
  user.value = %s;
  password.value = %s;
  submit.click();
})()"""

_STORE = getattr(browsertab.AbstractTab, "_isep_store", None)
if _STORE is None:
    _STORE = types.SimpleNamespace()
    browsertab.AbstractTab._isep_store = _STORE


def _fill(tab, form, process, code):
    output = bytes(process.readAllStandardOutput()).decode()
    process.deleteLater()
    lines = output.split("\n")
    if code != 0 or len(lines) < 2 or not lines[0] or not lines[1]:
        message.error("ISEP autologin: no credentials in the keyring, run isep-login")
        return
    tab.run_js_async(
        _FILL % (json.dumps(form), json.dumps(lines[0]), json.dumps(lines[1]))
    )


def _lookup(tab, form, found):
    if not found:
        return
    tab._isep_login_at = time.monotonic()
    process = QProcess(tab)
    process.finished.connect(lambda code, _status: _fill(tab, form, process, code))
    process.start("isep-login", ["get"])


def _loaded(tab, ok):
    url = tab.url()
    form = _FORMS.get(url.host())
    if not ok or form is None or url.scheme() != "https":
        return
    last = getattr(tab, "_isep_login_at", None)
    if last is not None and time.monotonic() - last < _RETRY:
        return
    tab.run_js_async(
        f"!!document.querySelector({json.dumps(form[1])})",
        lambda found: _lookup(tab, form, found),
    )


def _hook():
    original = browsertab.AbstractTab._on_load_finished

    @functools.wraps(original)
    def wrapper(self, ok):
        original(self, ok)
        with contextlib.suppress(Exception):
            _STORE.loaded(self, ok)

    browsertab.AbstractTab._on_load_finished = wrapper


_STORE.loaded = _loaded

if not getattr(_STORE, "hooked", False):
    _hook()
    _STORE.hooked = True
