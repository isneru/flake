import os

from qutebrowser.browser import greasemonkey
from qutebrowser.config import config, configexc, configfiles
from qutebrowser.mainwindow import mainwindow
from qutebrowser.misc import objects, quitter
from qutebrowser.qt.core import QFileSystemWatcher, QTimer
from qutebrowser.utils import message, standarddir

_TRIGGER = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}",
    "qute-reload",
)
_WATCHER = "_notch_reload_watcher"
_HOOKED = "_notch_reload_hooked"
_SCHEME = "_notch_started_scheme"


def _ensure_trigger():
    if not os.path.exists(_TRIGGER):
        open(_TRIGGER, "a").close()


def _reload():
    watcher = getattr(objects.qapp, _WATCHER)
    if _TRIGGER not in watcher.files():
        _ensure_trigger()
        watcher.addPath(_TRIGGER)

    try:
        configfiles.read_config_py(standarddir.config_py())
    except configexc.ConfigFileErrors as e:
        message.error(str(e))

    greasemonkey.greasemonkey_reload(quiet=True)

    if config.val.colors.webpage.preferred_color_scheme != getattr(
        objects.qapp, _SCHEME
    ):
        QTimer.singleShot(0, quitter.restart)


def _install():
    if getattr(objects.qapp, _WATCHER, None) is not None:
        return
    setattr(objects.qapp, _SCHEME, config.val.colors.webpage.preferred_color_scheme)
    _ensure_trigger()
    watcher = QFileSystemWatcher(objects.qapp)
    setattr(objects.qapp, _WATCHER, watcher)
    watcher.addPath(_TRIGGER)
    watcher.fileChanged.connect(lambda *_: _reload())


if not getattr(mainwindow.MainWindow, _HOOKED, False):
    _original = mainwindow.MainWindow.__init__

    def _wrapper(self, *args, **kwargs):
        _original(self, *args, **kwargs)
        _install()

    mainwindow.MainWindow.__init__ = _wrapper
    setattr(mainwindow.MainWindow, _HOOKED, True)
