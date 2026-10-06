pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/quickshell/localsend"

    property var peers: []
    property var incoming: []
    property var transfers: []
    property string alias: ""
    property string dest: ""
    property bool alive: false

    readonly property var ask: incoming.length > 0 ? incoming[0] : null
    readonly property var running: transfers.find(t => t.state === "running") ?? null

    onAskChanged: {
        if (ask)
            NotchState.open("send");
        else if (NotchState.panel === "send" && NotchState.isExpanded)
            NotchState.close();
    }

    property bool seeded: false
    property string lastDone: ""
    function finished(list) {
        return list.find(x => x.state === "done" || x.state === "declined" || x.state === "failed") ?? null;
    }

    onTransfersChanged: {
        const t = finished(transfers);
        if (!t || t.id === lastDone)
            return;
        lastDone = t.id;
        const many = t.count > 1;
        if (t.state !== "done") {
            NotchState.showOsd("lsdone", {
                label: t.state === "declined" ? t.peer + " declined" : "Transfer failed",
                sub: t.error || t.name,
                bad: true
            });
            return;
        }
        NotchState.showOsd("lsdone", {
            label: t.dir === "in"
                ? (many ? "Received " + t.count + " files" : "Received " + t.name)
                : (many ? "Sent " + t.count + " files to " + t.peer : "Sent " + t.name + " to " + t.peer),
            sub: t.dir === "in" ? dest : ""
        });
    }

    function deviceIcon(kind) {
        switch (kind) {
        case "mobile": return "smartphone";
        case "web": return "public";
        case "headless": return "terminal";
        case "server": return "dns";
        default: return "computer";
        }
    }

    function fileIcon(f) {
        const mime = (f?.type ?? "").split("/")[0];
        if (mime === "image") return "image";
        if (mime === "video") return "movie";
        if (mime === "audio") return "music_note";
        if (mime === "text") return "description";
        const e = (f?.name ?? "").split(".").pop().toLowerCase();
        if (e === "pdf") return "picture_as_pdf";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].includes(e)) return "folder_zip";
        return "draft";
    }

    function fmtSize(n) {
        return Shelf.fmtSize(n) || "0 B";
    }

    function fmtBytes(n) {
        return String(n ?? 0).replace(/\B(?=(\d{3})+(?!\d))/g, " ") + " B";
    }

    function fmtWhen(iso) {
        if (!iso)
            return "";
        const d = new Date(iso);
        if (isNaN(d.getTime()))
            return iso;
        const now = new Date();
        const clock = Qt.formatDateTime(d, "HH:mm");
        if (d.toDateString() === now.toDateString())
            return "today " + clock;
        if (d.getFullYear() === now.getFullYear())
            return Qt.formatDateTime(d, "d MMM ") + clock;
        return Qt.formatDateTime(d, "d MMM yyyy ") + clock;
    }

    function summary(req) {
        const n = req?.count ?? 0;
        return n === 1 ? (req.files[0]?.name ?? "a file") : n + " files";
    }

    property var outbox: []

    function decodeAll(urls) {
        const out = [];
        for (const u of urls) {
            const p = Shelf.decode(u);
            if (p && !out.includes(p))
                out.push(p);
        }
        return out;
    }

    function stage(urls) {
        const fresh = decodeAll(urls).filter(p => !outbox.includes(p));
        if (fresh.length)
            outbox = outbox.concat(fresh);
        return fresh.length;
    }

    function stageShelf() {
        return stage(Shelf.items.filter(i => i.state === "file").map(i => i.path));
    }

    property var sizes: ({})
    readonly property int outboxBytes: outbox.reduce((n, p) => n + (sizes[p] ?? 0), 0)

    onOutboxChanged: probe()

    Process {
        id: sizer
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = ({});
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    seen[line.slice(tab + 1)] = parseInt(line.slice(0, tab)) || 0;
                }
                root.sizes = seen;
            }
        }
    }

    function probe() {
        if (!outbox.length || sizer.running)
            return;
        sizer.command = ["sh", "-c",
            'for p in "$@"; do printf "%s\t%s\n" "$(du -sb "$p" 2>/dev/null | cut -f1)" "$p"; done',
            "sh"].concat(outbox);
        sizer.running = true;
    }

    property string compose: ""

    readonly property string pasteScript: `
        dir=$XDG_RUNTIME_DIR
        [ -n "$dir" ] || dir=/tmp
        dir=$dir/quickshell/localsend/outbox
        types=$(wl-paste --list-types 2>/dev/null || true)
        has() { printf "%s\\n" "$types" | grep -qx "$1"; }
        uris() { sed -e 's/\\r$//' -e '/^#/d' -e '/^$/d' -e '/^copy$/d' -e '/^cut$/d'; }

        if has x-special/gnome-copied-files; then
            printf "files\\n"
            wl-paste --type x-special/gnome-copied-files | uris
        elif has text/uri-list; then
            printf "files\\n"
            wl-paste --type text/uri-list | uris
        else
            bin=$(printf "%s\\n" "$types" | grep -m1 "^image/" || true)
            [ -n "$bin" ] || bin=$(printf "%s\\n" "$types" \\
                | grep -E "^(audio|video|application|font|model)/" \\
                | grep -vE "x-internal|-source-|x-qt-image" | head -n1)
            if [ -n "$bin" ]; then
                mkdir -p "$dir"
                find "$dir" -maxdepth 1 -type f -mtime +0 -delete 2>/dev/null
                ext=$(printf %s "$bin" | cut -d/ -f2 | sed -e 's/^x-//' -e 's/[;+].*$//')
                case "$ext" in
                jpeg) ext=jpg ;;
                octet-stream) ext=bin ;;
                esac
                f=$dir/clipboard-$(date +%Y%m%d-%H%M%S).$ext
                wl-paste --type "$bin" > "$f" && printf "files\\n%s\\n" "$f"
            else
                body=$(wl-paste --no-newline 2>/dev/null)
                if [ -e "$body" ]; then
                    printf "files\\n%s\\n" "$body"
                else
                    printf "text\\n%s" "$body"
                fi
            fi
        fi
    `

    Process {
        id: paster
        command: ["sh", "-c", root.pasteScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                if (nl < 0)
                    return;
                const body = text.slice(nl + 1);
                if (text.slice(0, nl) === "files")
                    root.stage(body.split("\n").filter(l => l.length));
                else if (body)
                    root.compose = body;
            }
        }
    }

    function paste() {
        if (!paster.running)
            paster.running = true;
    }

    function clearCompose() {
        compose = "";
    }

    function sendText(peer) {
        if (!compose || !peer)
            return;
        send({ cmd: "send", peer: peer.fingerprint, text: compose });
        compose = "";
    }

    readonly property bool armed: outbox.length > 0 || compose.length > 0

    function unstage(path) {
        outbox = outbox.filter(p => p !== path);
    }

    function clearOutbox() {
        outbox = [];
    }

    function sendTo(peer) {
        if (!peer)
            return;
        if (compose) {
            sendText(peer);
            return;
        }
        if (!outbox.length)
            return;
        send({ cmd: "send", peer: peer.fingerprint, paths: outbox });
        outbox = [];
    }

    function sendPaths(peer, urls) {
        const paths = decodeAll(urls);
        if (paths.length && peer)
            send({ cmd: "send", peer: peer.fingerprint, paths: paths });
        return paths.length;
    }

    function name(path) {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    property bool scanning: false

    function scan() {
        send({ cmd: "scan" });
        scanning = true;
        scanTimer.restart();
    }

    Timer {
        id: scanTimer
        interval: 2500
        onTriggered: root.scanning = false
    }

    function accept(id) { send({ cmd: "accept", id: id }); }
    function deny(id) { send({ cmd: "deny", id: id }); }
    function cancel(id) { send({ cmd: "cancel", id: id }); }

    function send(cmd) {
        writer.createObject(root, {
            fifo: dir + "/control",
            payload: JSON.stringify(cmd) + "\n"
        });
    }

    FileView {
        id: file
        path: root.dir + "/state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: root.clear()
    }

    Timer {
        running: true
        repeat: true
        interval: (root.ask || root.running) ? 250 : (root.alive ? 2000 : 4000)
        onTriggered: file.reload()
    }

    function put(cur, next) {
        return JSON.stringify(cur) === JSON.stringify(next) ? cur : next;
    }

    function apply(txt) {
        try {
            const j = JSON.parse(txt);
            peers = put(peers, j.peers ?? []);
            incoming = put(incoming, j.incoming ?? []);
            if (!seeded) {
                seeded = true;
                lastDone = finished(j.transfers ?? [])?.id ?? "";
            }
            transfers = put(transfers, j.transfers ?? []);
            alias = j.self?.alias ?? "";
            dest = j.self?.dest ?? "";
            alive = true;
        } catch (e) {
            clear();
        }
    }

    function clear() {
        peers = [];
        incoming = [];
        transfers = [];
        alive = false;
    }

    Component {
        id: writer

        Process {
            required property string fifo
            required property string payload

            command: ["timeout", "5", "sh", "-c", 'test -p "$1" && exec cat > "$1"', "sh", fifo]
            running: true
            stdinEnabled: true

            onStarted: {
                write(payload);
                stdinEnabled = false;
            }
            onExited: destroy()
        }
    }
}
