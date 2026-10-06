config.load_autoconfig(False)  # this file is the whole truth; :set is not saved


c.auto_save.session = True
c.tabs.show = "always"
c.tabs.title.format = "{audio}{current_title}"
c.tabs.title.alignment = "left"
c.tabs.indicator.width = 0
c.tabs.favicons.scale = 0.8
c.tabs.padding = {"top": 2, "bottom": 2, "left": 8, "right": 8}
c.downloads.position = "bottom"
c.downloads.remove_finished = 10000
c.completion.open_categories = [
    "searchengines",
    "quickmarks",
    "bookmarks",
    "history",
    "filesystem",
]
c.completion.height = "25%"


c.statusbar.padding = {"top": 2, "bottom": 2, "left": 2, "right": 2}
c.content.notifications.presenter = "libnotify"
c.content.autoplay = True

_start_page = (config.datadir / "start.html").as_uri()
c.url.start_pages = [_start_page]
c.url.default_page = _start_page

config.set(
    "content.local_content_can_access_remote_urls", True, f"{config.datadir.as_uri()}/*"
)


c.content.blocking.enabled = True
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/legacy.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/badware.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/quick-fixes.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/resource-abuse.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/unbreak.txt",
    "https://easylist.to/easylist/easylist.txt",
]


c.content.webgl = True
c.content.canvas_reading = False
c.content.geolocation = "ask"
c.content.webrtc_ip_handling_policy = "all-interfaces"
c.content.cookies.accept = "all"
c.content.cookies.store = True
c.content.dns_prefetch = False
c.content.canvas_reading = True
c.content.headers.referer = "always"
c.content.javascript.can_open_tabs_automatically = True
c.content.javascript.clipboard = "access-paste"
c.content.pdfjs = True

_chrome_ua = (
    "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) "
    "{upstream_browser_key}/{upstream_browser_version_short} Safari/{webkit_version}"
)
for _pattern in (
    "https://*.microsoft.com/*",
    "https://*.cloud.microsoft/*",
    "https://*.sharepoint.com/*",
    "https://*.ui.com/*",
):
    config.set("content.headers.user_agent", _chrome_ua, _pattern)

c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.policy.images = "never"
config.set("colors.webpage.darkmode.enabled", False, "file://*")


c.hints.mode = "number"


c.aliases["open"] = "spawn --userscript qute-open"


config.bind("cs", "config-source")
config.bind("T", "hint links tab")
config.bind("pt", "open -t -- {clipboard}")
config.bind("st", "config-cycle tabs.show always never")
config.bind("ss", "config-cycle statusbar.show always never")
config.bind("sd", "config-cycle colors.webpage.darkmode.enabled")

config.bind("cy", "hint links yank")

config.unbind("v")

_QUICKMARKS = {
    "bindings": "qute://bindings/",
    "gh": "https://github.com/",
    "red": "https://reddit.com",
    "yt": "https://youtube.com/",
    "x": "https://x.com/",
    "tt": "https://x.com/",
    "wall": "https://wallhaven.cc/toplist",
}

_quickmarks_file = config.configdir / "quickmarks"
_existing = {}
if _quickmarks_file.exists():
    for _line in _quickmarks_file.read_text().splitlines():
        if _line.strip():
            _name, _, _url = _line.partition(" ")
            _existing[_name] = _url

_marks = {**_existing, **_QUICKMARKS}
if _marks != _existing:
    _quickmarks_file.write_text(
        "".join(f"{_name} {_url}\n" for _name, _url in _marks.items())
    )


config.bind("<Ctrl-y>", "spawn --userscript qute-ytdl")
config.bind("<Ctrl-m>", "spawn --userscript qute-mpv")
config.bind(";m", "hint links userscript qute-mpv")
config.bind("<Ctrl-g>", "spawn --userscript qute-clone")


for _generated in ("theme.py", "downloads.py", "statusbar.py"):
    if (config.configdir / _generated).exists():
        config.source(_generated)

config.source("reload.py")
