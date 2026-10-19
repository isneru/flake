import pathlib

from qutebrowser.api import cmdutils
from qutebrowser.browser import greasemonkey
from qutebrowser.config import config as qconfig
from qutebrowser.misc import objects
from qutebrowser.utils import standarddir, urlmatch

_OPTION = "colors.webpage.darkmode.enabled"
_SITES = pathlib.Path(standarddir.data(), "light-sites")
_SCRIPT = pathlib.Path(standarddir.data(), "greasemonkey", "light-sites.js")

_LIGHT = """(function () {
    "use strict";

    const root = document.documentElement;
    root.style.setProperty("color-scheme", "light", "important");

    const clear = (el) => !el || getComputedStyle(el).backgroundColor === "rgba(0, 0, 0, 0)";
    if (clear(root) && clear(document.body)) {
        root.style.backgroundColor = "#fff";
        root.dataset.quteLight = "";
    }
})();
"""

_DARK = """(function () {
    "use strict";

    const root = document.documentElement;
    root.style.removeProperty("color-scheme");
    if ("quteLight" in root.dataset) {
        root.style.removeProperty("background-color");
        delete root.dataset.quteLight;
    }
})();
"""


def _pattern(host):
    return urlmatch.UrlPattern(f"*://{host}/*")


def _write_script(sites):
    if not sites:
        _SCRIPT.unlink(missing_ok=True)
        return
    matches = "".join(f"// @match        *://{host}/*\n" for host in sites)
    _SCRIPT.parent.mkdir(parents=True, exist_ok=True)
    _SCRIPT.write_text(
        "// ==UserScript==\n"
        "// @name         Light sites\n"
        f"{matches}"
        "// @run-at       document-end\n"
        "// @grant        none\n"
        "// ==/UserScript==\n\n" + _LIGHT
    )


def _toggle(tab):
    host = tab.url().host()
    if not host:
        return
    sites = _SITES.read_text().split() if _SITES.exists() else []
    if host in sites:
        sites.remove(host)
        qconfig.instance.unset(_OPTION, pattern=_pattern(host))
        js = _DARK
    else:
        sites.append(host)
        qconfig.instance.set_obj(_OPTION, False, pattern=_pattern(host))
        js = _LIGHT
    _SITES.write_text("".join(f"{site}\n" for site in sites))
    _write_script(sites)
    greasemonkey.greasemonkey_reload(quiet=True)
    tab.settings.update_for_url(tab.url())
    tab.run_js_async(js)


_sites = _SITES.read_text().split() if _SITES.exists() else []
for _host in _sites:
    config.set(_OPTION, False, f"*://{_host}/*")
_write_script(_sites)

if "darkmode-site" not in objects.commands:

    @cmdutils.register(name="darkmode-site")
    @cmdutils.argument("tab", value=cmdutils.Value.cur_tab)
    def _darkmode_site(tab):
        """Toggle forced dark mode for the current host and remember it."""
        _toggle(tab)
