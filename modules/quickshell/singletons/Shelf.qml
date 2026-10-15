pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var items: []
    property bool loaded: false

    readonly property int count: items.length
    readonly property int gone: items.filter(i => i.state === "missing").length

    function decode(u) {
        const s = String(u ?? "");
        if (s.startsWith("file://"))
            return decodeURIComponent(s.slice(7));
        return s.startsWith("/") ? s : "";
    }

    function name(p) {
        return p.slice(p.lastIndexOf("/") + 1);
    }
    function dir(p) {
        const i = p.lastIndexOf("/");
        return i <= 0 ? "/" : p.slice(0, i);
    }
    function ext(p) {
        const n = name(p);
        const i = n.lastIndexOf(".");
        return i <= 0 ? "" : n.slice(i + 1).toLowerCase();
    }

    readonly property var imageExts: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "avif"]

    function isImage(it) {
        return it.state === "file" && imageExts.includes(ext(it.path));
    }

    readonly property var extIcons: [
        { icon: "image", exts: imageExts.concat(["svg"]) },
        { icon: "movie", exts: ["mp4", "mkv", "webm", "mov", "avi"] },
        { icon: "music_note", exts: ["mp3", "flac", "wav", "ogg", "opus", "m4a"] },
        { icon: "picture_as_pdf", exts: ["pdf"] },
        { icon: "folder_zip", exts: ["zip", "tar", "gz", "xz", "zst", "7z", "rar"] },
        { icon: "description", exts: ["txt", "md", "org", "doc", "docx"] },
        { icon: "code", exts: ["nix", "qml", "js", "ts", "py", "sh", "el", "lua", "c", "cpp", "h", "rs", "go", "json", "toml", "yaml", "yml"] }
    ]

    function iconFor(it) {
        if (it.state === "missing")
            return "link_off";
        if (it.state === "dir")
            return "folder";
        const e = ext(it.path);
        return extIcons.find(g => g.exts.includes(e))?.icon ?? "draft";
    }

    function fmtSize(n) {
        if (!(n > 0))
            return "";
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        let v = n;
        while (v >= 1024 && i < u.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? v : v.toFixed(v < 10 ? 1 : 0)) + " " + u[i];
    }

    signal dropSummary(string label, string sub)

    property var pending: []
    property int pendingDup: 0
    property int pendingRejected: 0

    function add(urls) {
        const have = items.map(i => i.path);
        const fresh = [];
        let dup = 0;
        let rejected = 0;
        for (const u of urls) {
            const p = decode(u);
            if (!p) {
                rejected++;
                continue;
            }
            if (have.includes(p)) {
                dup++;
                continue;
            }
            have.push(p);
            fresh.push({ path: p, added: Date.now(), state: "unknown", size: 0 });
        }

        pending = fresh.map(i => i.path);
        pendingDup = dup;
        pendingRejected = rejected;

        if (!fresh.length) {
            announce();
            return 0;
        }
        items = fresh.reverse().concat(items);
        save();
        probe();
        return fresh.length;
    }

    function announce() {
        const paths = pending;
        const dup = pendingDup;
        const rejected = pendingRejected;
        pending = [];
        pendingDup = 0;
        pendingRejected = 0;

        const held = items.filter(i => paths.includes(i.path));
        const dirs = held.filter(i => i.state === "dir").length;
        const files = held.length - dirs;
        const n = held.length;

        let label;
        if (n === 0)
            label = rejected > 0 ? "Not a local file" : "Already on the shelf";
        else if (dirs && !files)
            label = n + (n === 1 ? " folder added" : " folders added");
        else if (files && !dirs)
            label = n + (n === 1 ? " file added" : " files added");
        else
            label = n + " items added";

        const notes = [];
        if (n > 0)
            notes.push(count + " held");
        if (dup > 0 && n > 0)
            notes.push(dup + " already there");
        if (rejected > 0)
            notes.push(n > 0 ? rejected + " not on disk" : "only files on disk");

        dropSummary(label, notes.join(" - "));
    }

    function remove(path) {
        items = items.filter(i => i.path !== path);
        save();
    }

    function clear() {
        items = [];
        save();
    }

    function pruneMissing() {
        items = items.filter(i => i.state !== "missing");
        save();
    }

    function run(cmd) {
        Quickshell.execDetached(cmd);
    }

    function open(path) {
        run(["xdg-open", path]);
    }
    function reveal(it) {
        run(["xdg-open", it.state === "dir" ? it.path : dir(it.path)]);
    }
    function copyPath(path) {
        run(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", path]);
    }
    function copyFile(path) {
        run(["sh", "-c", 'printf "copy\n%s" "$1" | wl-copy --type x-special/gnome-copied-files', "sh", uri(path)]);
    }

    function uri(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    property bool probeQueued: false

    Process {
        id: stat
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = ({});
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const head = line.slice(0, tab).split(" ");
                    seen[line.slice(tab + 1)] = {
                        state: head[0] === "d" ? "dir" : (head[0] === "f" ? "file" : "missing"),
                        size: parseInt(head[1]) || 0
                    };
                }
                root.items = root.items.map(it => seen[it.path] ? Object.assign({}, it, seen[it.path]) : it);

                if (root.probeQueued) {
                    root.probeQueued = false;
                    root.probe();
                } else if (root.pending.length) {
                    root.announce();
                }
            }
        }
    }

    readonly property string probeScript: 'for p in "$@"; do if [ -d "$p" ]; then s="d 0"; elif [ -e "$p" ]; then s="f $(stat -c %s "$p" 2>/dev/null || echo 0)"; else s="x 0"; fi; printf "%s\t%s\n" "$s" "$p"; done'

    function probe() {
        if (!items.length)
            return;
        if (stat.running) {
            probeQueued = true;
            return;
        }
        stat.command = ["sh", "-c", probeScript, "sh"].concat(items.map(i => i.path));
        stat.running = true;
    }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/shelf.json`
        onLoaded: {
            root.apply(text());
            root.loaded = true;
        }
        onLoadFailed: {
            root.loaded = true;
            root.save();
        }
    }

    function apply(txt) {
        try {
            const j = JSON.parse(txt);
            items = (j.items ?? []).filter(i => i && typeof i.path === "string").map(i => ({
                path: i.path,
                added: i.added ?? 0,
                state: "unknown",
                size: 0
            }));
        } catch (e) {
            items = [];
        }
        probe();
    }

    property bool _ready: false
    Component.onCompleted: _ready = true
    function save() {
        if (!_ready)
            return;
        file.setText(JSON.stringify({
            items: items.map(i => ({ path: i.path, added: i.added }))
        }, null, 2));
    }
}
