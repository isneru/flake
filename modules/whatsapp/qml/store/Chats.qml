pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateDir: `${Quickshell.env("HOME")}/.local/state/whatsapp`

    property var index: ({})
    property bool ready: false
    readonly property var chats: root.index.chats ?? []
    readonly property string state: root.index.state ?? ""
    readonly property string me: root.index.me ?? ""

    property string jid: ""
    property string query: ""
    property bool archived: false
    property string error: ""
    property var loading: ({})
    property var outbox: []
    property var reply: null
    property var attachments: []

    signal compose
    signal textPaste

    readonly property var chat: root.chats.find(c => c.jid === root.jid) ?? null
    readonly property ListModel thread: ListModel {}

    readonly property var shown: {
        const q = root.query.trim().toLowerCase();
        if (q)
            return root.chats.filter(c => c.name.toLowerCase().includes(q));
        return root.chats.filter(c => c.archived === root.archived);
    }

    readonly property int archivedUnread: root.chats.filter(c => c.archived && c.unread > 0).length

    readonly property bool active: Qt.application.state === Qt.ApplicationActive

    onActiveChanged: root.markRead()
    onChatChanged: root.markRead()

    FileView {
        path: `${root.stateDir}/chats.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.index = JSON.parse(text());
            } catch (e) {
                root.index = {};
            }
            root.ready = true;
        }
        onLoadFailed: {
            root.index = {};
            root.ready = true;
        }
    }

    FileView {
        path: root.jid ? `${root.stateDir}/chat/${root.jid}.json` : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const detail = JSON.parse(text());
                if (detail.jid === root.jid)
                    root.sync(detail.messages ?? []);
            } catch (e) {}
        }
    }

    function flat(m): var {
        const row = {
            key: m.id,
            me: m.me,
            who: m.who ?? "",
            ts: m.ts,
            kind: m.kind,
            text: m.text ?? "",
            file: m.file ?? "",
            name: m.name ?? "",
            mime: m.mime ?? "",
            size: m.size ?? 0,
            status: m.status ?? "",
            edited: !!m.edited,
            deleted: !!m.deleted,
            quoteWho: m.quote ? m.quote.who : "",
            quoteText: m.quote ? m.quote.text : "",
            thumb: m.thumb ?? "",
            w: m.w ?? 0,
            h: m.h ?? 0
        };
        row.sig = JSON.stringify(row);
        return row;
    }

    function sync(messages: var): void {
        const rows = messages.map(root.flat);
        const keep = new Set(rows.map(r => r.key));
        for (let i = root.thread.count - 1; i >= 0; i--)
            if (!keep.has(root.thread.get(i).key))
                root.thread.remove(i);
        for (let i = 0; i < rows.length; i++) {
            if (i < root.thread.count && root.thread.get(i).key === rows[i].key) {
                if (root.thread.get(i).sig !== rows[i].sig)
                    root.thread.set(i, rows[i]);
            } else {
                root.thread.insert(i, rows[i]);
            }
        }
        while (root.thread.count > rows.length)
            root.thread.remove(root.thread.count - 1);
    }

    function select(jid: string): void {
        if (jid === root.jid)
            return;
        root.thread.clear();
        root.reply = null;
        root.attachments = [];
        root.jid = jid;
        root.opened();
    }

    function markRead(): void {
        if (root.chat && root.active && root.chat.unread > 0)
            Quickshell.execDetached(["neru", "whatsapp", "open", root.jid]);
    }

    function opened(): void {
        if (root.jid)
            Quickshell.execDetached(["neru", "whatsapp", "open", root.jid]);
    }

    function queue(args: var): void {
        if (root.reply)
            args.push(root.reply.key);
        root.reply = null;
        root.outbox = root.outbox.concat([args]);
        root.pump();
    }

    function send(text: string): void {
        if (root.jid && text.trim())
            root.queue(["neru", "whatsapp", "send", root.jid, text]);
    }

    function sendFile(path: string, as: string): void {
        root.attachments = root.attachments.slice(1);
        if (root.jid)
            root.queue(["neru", "whatsapp", "file", root.jid, path, as]);
    }

    function pump(): void {
        if (sender.running || !root.outbox.length)
            return;
        sender.command = root.outbox[0];
        root.outbox = root.outbox.slice(1);
        sender.running = true;
    }

    function quote(m): void {
        if (m.deleted)
            return;
        root.reply = {
            key: m.key,
            who: m.me ? "You" : (m.who || (root.chat ? root.chat.name : "")),
            text: root.label(m.kind, m.text, m.name)
        };
        root.compose();
    }

    function attach(path: string): void {
        if (root.jid && path)
            root.attachments = root.attachments.concat([path]);
    }

    function isImage(path: string): bool {
        return /\.(png|jpe?g|gif|webp|bmp|avif|tiff?)$/i.test(path);
    }

    function pick(): void {
        if (root.jid)
            Quickshell.execDetached(["sh", "-c", 'f=$(mktemp) && kitty --class whatsapp-picker --title "Send to WhatsApp" -e yazi --chooser-file="$f"; while IFS= read -r p || [ -n "$p" ]; do quickshell ipc -c whatsapp call whatsapp attach "$p"; done < "$f"; rm -f "$f"']);
    }

    function paste(): void {
        if (!paster.running)
            paster.running = true;
    }

    Process {
        id: paster
        command: ["whatsapp-paste"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path)
                    root.attach(path);
                else
                    root.textPaste();
            }
        }
    }

    Process {
        id: sender
        stderr: StdioCollector {
            id: sendErrors
        }
        onExited: code => {
            root.error = code === 0 ? "" : sendErrors.text.trim();
            root.pump();
        }
    }

    function load(key: string): void {
        root.loading = Object.assign({}, root.loading, {
            [key]: true
        });
        Quickshell.execDetached(["sh", "-c", 'p=$(whatsapp fetch "$1" "$2" 2>&1) || notify-send -a WhatsApp "Download failed" "$p"', "sh", root.jid, key]);
    }

    function save(key: string): void {
        Quickshell.execDetached(["sh", "-c", 'p=$(whatsapp save "$1" "$2" 2>&1) && notify-send -a WhatsApp "Saved" "$p" || notify-send -a WhatsApp "Save failed" "$p"', "sh", root.jid, key]);
    }

    function openMedia(m): void {
        if (m.file) {
            Quickshell.execDetached(["xdg-open", m.file]);
            return;
        }
        root.loading = Object.assign({}, root.loading, {
            [m.key]: true
        });
        Quickshell.execDetached(["sh", "-c", 'p=$(whatsapp fetch "$1" "$2" 2>&1) && xdg-open "$p" || notify-send -a WhatsApp "Download failed" "$p"', "sh", root.jid, m.key]);
    }

    function stamp(ms: real): string {
        const day = new Date(ms);
        const now = new Date();
        if (day.toDateString() === now.toDateString())
            return Qt.formatDateTime(day, "HH:mm");
        const yesterday = new Date(now);
        yesterday.setDate(now.getDate() - 1);
        if (day.toDateString() === yesterday.toDateString())
            return "Yesterday";
        if (now - day < 6 * 86400000)
            return Qt.formatDateTime(day, "ddd");
        return Qt.formatDateTime(day, "dd/MM/yy");
    }

    function label(kind: string, text: string, name: string): string {
        const labels = {
            image: "Photo",
            sticker: "Sticker",
            video: "Video",
            audio: "Voice message",
            document: name || "Document",
            location: "Location",
            contact: "Contact",
            poll: "Poll"
        };
        const l = labels[kind] ?? "";
        if (!l)
            return text;
        return text ? `${l}: ${text}` : l;
    }

    function glyph(kind: string): string {
        return {
            image: "image",
            sticker: "sentiment_satisfied",
            video: "movie",
            audio: "mic",
            document: "description",
            location: "location_on",
            contact: "person",
            poll: "ballot"
        }[kind] ?? "";
    }

    function bytes(n: real): string {
        if (n < 1024)
            return `${n} B`;
        if (n < 1048576)
            return `${Math.round(n / 1024)} KB`;
        return `${(n / 1048576).toFixed(1)} MB`;
    }
}
