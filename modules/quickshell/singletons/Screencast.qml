pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/singletons"

Singleton {
    id: root

    property var queue: []
    readonly property var req: queue.length > 0 ? queue[0] : null
    readonly property bool pending: req !== null

    readonly property var windows: parseWindows(req?.windows ?? "")

    readonly property int reuseWindow: 90000
    readonly property int maxReuse: 3
    property string lastPick: ""
    property double lastPickAt: 0
    property int reuses: 0

    property bool picking: false
    property bool pickToken: false

    onReqChanged: {
        if (!req) {
            expiry.stop();
            return;
        }
        pickToken = req.allowToken;
        expiry.restart();
    }

    Timer {
        id: expiry
        interval: 210000
        onTriggered: root.cancelAll()
    }

    function parseWindows(raw) {
        const out = [];
        for (const rec of raw.split("[HA>]")) {
            if (!rec)
                continue;
            const handle = rec.split("[HC>]");
            if (handle.length < 2)
                continue;
            const cls = handle[1].split("[HT>]");
            const title = (cls[1] ?? "").split("[HE>]");
            out.push({
                handle: handle[0],
                appId: cls[0] ?? "",
                title: title[0] ?? "",
                address: title[1] ?? "0"
            });
        }
        return out;
    }

    function toplevelFor(w) {
        const hex = Number(w.address).toString(16);
        for (const t of Hyprland.toplevels.values) {
            if (hex !== "0" && (t.address ?? "").replace(/^0x/, "").toLowerCase() === hex)
                return t.wayland;
        }
        for (const t of Hyprland.toplevels.values) {
            if ((t.lastIpcObject?.class ?? "") === w.appId && (t.title ?? "") === w.title)
                return t.wayland;
        }
        return null;
    }

    function request(json) {
        let r;
        try {
            r = JSON.parse(json);
        } catch (e) {
            return "bad request";
        }
        if (!r.id || !r.fifo)
            return "bad request";
        enqueue({
            id: r.id,
            fifo: r.fifo,
            windows: r.windows ?? "",
            allowToken: r.allowToken === true
        });
        return "queued";
    }

    function enqueue(r) {
        if (reusable(r)) {
            reuses++;
            lastPickAt = Date.now();
            answer(r, lastPick);
            return;
        }
        queue = queue.concat([r]);
        NotchState.open("share");
    }

    function reusable(r) {
        if (!lastPick || reuses >= maxReuse)
            return false;
        if (Date.now() - lastPickAt > reuseWindow)
            return false;
        const sel = lastPick.slice(lastPick.indexOf("/") + 1);
        if (sel.startsWith("window:"))
            return parseWindows(r.windows ?? "").some(w => w.handle === sel.slice(7));
        const name = sel.startsWith("screen:") ? sel.slice(7) : sel.slice(7, sel.indexOf("@"));
        return Quickshell.screens.some(s => s.name === name);
    }

    function pick(sel) {
        if (!req)
            return;
        const payload = (pickToken ? "r" : "") + "/" + sel;
        lastPick = payload;
        lastPickAt = Date.now();
        reuses = 0;
        answer(req, payload);
    }

    function cancel() {
        if (req)
            deny(req);
    }

    function cancelAll() {
        const rest = queue.slice();
        queue = [];
        for (const r of rest)
            deny(r);
    }

    function deny(r) {
        forget();
        answer(r, "cancel");
    }

    function abandon(id) {
        const r = queue.find(q => q.id === id);
        if (r)
            deny(r);
    }

    function forget() {
        lastPick = "";
        reuses = 0;
    }

    function answer(r, payload) {
        queue = queue.filter(q => q.id !== r.id);
        replier.createObject(root, {
            fifo: r.fifo,
            payload: payload + "\n"
        });
        if (queue.length > 0)
            NotchState.open("share");
    }

    function pickRegion() {
        if (picking)
            return;
        picking = true;
        Quickshell.execDetached(["notch-share-picker", "--region"]);
    }

    function region(raw) {
        if (!picking)
            return;
        picking = false;
        const f = raw.trim().split(" ");
        if (f.length !== 5)
            return;
        pick(`region:${f[0]}@${f[1]},${f[2]},${f[3]},${f[4]}`);
    }

    Component {
        id: replier

        Process {
            required property string fifo
            required property string payload

            command: ["timeout", "10", "sh", "-c", 'test -p "$1" && exec cat > "$1"', "sh", fifo]
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
