pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "root:/singletons"

Singleton {
    id: root

    property var history: []
    property var current: null
    property int stack: 1
    readonly property int count: groups.length

    signal raise(var n)

    NotificationServer {
        id: server

        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: false
        keepOnReload: true

        onNotification: n => {
            n.tracked = true;

            const item = {
                id: n.id,
                key: root.keyOf(n),
                count: 1,
                app: n.appName || n.desktopEntry || "Unknown",
                appIcon: n.appIcon || "",
                image: n.image || "",
                summary: n.summary || "",
                body: root.strip(n.body || ""),
                urgency: n.urgency,
                resident: n.resident,
                time: new Date(),
                notification: n,
                icon: root.glyphFor(n)
            };

            if (n.lastGeneration) {
                if (!n.transient)
                    root.restore(item);
                return;
            }

            if (!n.transient) {
                const h = root.history.slice();
                const at = h.findIndex(e => e.id === item.id);
                const same = at < 0 ? h.findIndex(e => e.key === item.key) : -1;

                if (at >= 0) {
                    item.count = h[at].count;
                    h[at] = item;
                } else if (same >= 0) {
                    item.count = (h[same].count ?? 1) + 1;
                    h.splice(same, 1);
                    h.unshift(item);
                } else {
                    h.unshift(item);
                }
                root.history = root.pruned(h).slice(0, 60);
                root.cache(item);
                saveSoon.restart();
            }

            const dnd = NotchState.toggles.dnd && n.urgency !== NotificationUrgency.Critical;
            if (dnd || NotchState.isExpanded) {
                root.stack = 1;
                return;
            }

            const followUp = n.transient && root.gkeyOf(root.current) === root.gkeyOf(item);
            root.stack = (NotchState.isOsd && NotchState.osdKind === "notif") ? root.stack + (followUp ? 0 : 1) : 1;
            root.current = item;
            root.raise(item);
            NotchState.showOsd("notif", {
                app: item.app,
                title: item.summary,
                body: item.body,
                icon: item.icon,
                image: item.image || item.appIcon,
                action: root.primaryAction(item)?.text ?? "",
                urgent: n.urgency === NotificationUrgency.Critical,
                stack: root.stack,
                repeats: item.count,
                dwell: root.dwellFor(n)
            });
        }
    }

    Instantiator {
        model: server.trackedNotifications
        delegate: Connections {
            required property var modelData
            target: modelData
            function onClosed() { root.died(modelData); }
        }
    }

    property var pending: []
    property bool loaded: false

    function drain() {
        if (root.loaded)
            return;
        root.loaded = true;
        const q = root.pending;
        root.pending = [];
        for (const it of q)
            root.restore(it);
    }

    function restore(item) {
        if (!root.loaded) {
            root.pending = root.pending.concat([item]);
            return;
        }
        const h = root.history.slice();
        const at = h.findIndex(e => !e.notification && e.key === item.key);
        if (at >= 0) {
            item.count = h[at].count ?? 1;
            item.time = h[at].time;
            if (h[at].image.startsWith("file://") && item.image.startsWith("image://"))
                item.image = h[at].image;
            h[at] = item;
        } else {
            h.unshift(item);
        }
        h.sort((a, b) => b.time - a.time);
        root.history = root.pruned(h).slice(0, 60);
        root.cache(item);
        saveSoon.restart();
    }

    function died(n) {
        let hit = false;
        for (const e of root.history) {
            if (e.notification !== n)
                continue;
            e.notification = null;
            if (e.image.startsWith("image://"))
                e.image = "";
            hit = true;
        }
        if (hit)
            root.history = root.history.slice();
    }

    readonly property string cacheDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/quickshell/notif-images`

    Process {
        running: true
        command: ["mkdir", "-p", root.cacheDir]
    }

    function hashOf(str) {
        let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
        for (let i = 0; i < str.length; i++) {
            const ch = str.charCodeAt(i);
            h1 = Math.imul(h1 ^ ch, 2654435761);
            h2 = Math.imul(h2 ^ ch, 1597334677);
        }
        h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
        h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
        return (h2 >>> 0).toString(16).padStart(8, "0") + (h1 >>> 0).toString(16).padStart(8, "0");
    }

    property var cacheQueue: []

    function cache(item) {
        if (!item.image.startsWith("image://"))
            return;
        root.cacheQueue = root.cacheQueue.concat([({
            key: item.key,
            src: item.image,
            path: `${root.cacheDir}/${root.hashOf(item.key)}.png`
        })]);
    }

    function cached(job, ok) {
        if (ok) {
            let hit = false;
            for (const e of root.history) {
                if (e.key !== job.key || !e.image.startsWith("image://"))
                    continue;
                e.image = "file://" + job.path;
                hit = true;
            }
            if (hit) {
                root.history = root.history.slice();
                saveSoon.restart();
            }
        }
        root.cacheQueue = root.cacheQueue.slice(1);
    }

    Loader {
        active: root.cacheQueue.length > 0
        sourceComponent: PanelWindow {
            id: grabWin
            readonly property var job: root.cacheQueue[0]
            readonly property int side: 64

            anchors { top: true; left: true }
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-notif-cache"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                x: -1
                y: -1
                width: 1
                height: 1
            }

            Image {
                id: shot
                width: grabWin.side
                height: grabWin.side
                sourceSize.width: grabWin.side
                sourceSize.height: grabWin.side
                source: grabWin.job?.src ?? ""
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: false
                onStatusChanged: {
                    if (status === Image.Ready)
                        settle.restart();
                    else if (status === Image.Error)
                        root.cached(grabWin.job, false);
                }
            }

            Timer {
                id: settle
                interval: 300
                onTriggered: {
                    const job = grabWin.job;
                    const ok = shot.grabToImage(result => {
                        root.cached(job, result.saveToFile(job.path));
                    }, Qt.size(grabWin.side, grabWin.side));
                    if (!ok)
                        root.cached(job, false);
                }
            }

            Timer {
                running: true
                interval: 4000
                onTriggered: root.cached(grabWin.job, false)
            }
        }
    }

    function dwellFor(n) {
        const base = n.urgency === NotificationUrgency.Critical ? 6000 : 4200;
        const ms = Number(n.expireTimeout);
        return isFinite(ms) && ms > 0 ? Math.min(30000, Math.max(base, Math.round(ms))) : base;
    }

    function rowFor(item) {
        if (!item)
            return null;
        if (root.history.indexOf(item) >= 0)
            return item;
        const k = item.key ?? "";
        return k ? (root.history.find(h => h.key === k) ?? null) : null;
    }

    function actionsOf(item) {
        return root.rowFor(item)?.notification?.actions ?? [];
    }
    function labelled(a) {
        return (a?.text ?? "").trim() !== "";
    }
    function buttons(item) {
        return root.actionsOf(item).filter(a => a.identifier !== "default" && root.labelled(a));
    }
    function defaultAction(item) {
        return root.actionsOf(item).find(a => a.identifier === "default") ?? null;
    }
    function primaryAction(item) {
        const as = root.actionsOf(item);
        return as.find(a => a.identifier === "default" && root.labelled(a)) ?? as.find(a => root.labelled(a)) ?? null;
    }
    function invokePrimary(item) {
        root.invokeAction(item, root.primaryAction(item));
    }
    function invokeAction(item, action) {
        const row = root.rowFor(item);
        if (action)
            action.invoke();
        else
            root.focusApp(row ?? item);
        if (!row?.resident)
            root.dismiss(row ?? item);
        NotchState.close();
    }

    function focusApp(item) {
        const cls = (item?.app ?? "").replace(/[^A-Za-z0-9._-]/g, "");
        if (cls)
            Hyprland.dispatch(`hl.dsp.focus({ window = "class:(?i)${cls}" })`);
    }
    function closeOsd() {
        if (NotchState.mode === "osd" && NotchState.osdKind === "notif")
            NotchState.close();
    }

    function dismiss(item) {
        const row = root.rowFor(item);
        if (!row)
            return;
        row.notification?.dismiss();
        root.history = root.history.filter(h => h !== row);
        root.stack = 1;
        saveSoon.restart();
        root.closeOsd();
    }
    function clearAll() {
        for (const h of root.history)
            h.notification?.dismiss();
        root.history = [];
        root.stack = 1;
        save();
    }

    function keyOf(n) {
        return (n.appName || n.desktopEntry || "") + "\u0000" + (n.summary || "") + "\u0000" + root.strip(n.body || "");
    }

    function gkeyOf(item) {
        return (item?.app ?? "") + "\u0000" + (item?.summary ?? "");
    }

    readonly property int stackCap: 5

    readonly property var stackRules: [
        [/battery|power|upower|network|nm-|wifi|vpn|bluetooth|bluez|volume|audio|pipewire|update|upgrade/, "replace"]
    ]

    function policyFor(item) {
        if (item?.urgency === NotificationUrgency.Critical)
            return "never";
        const key = (item?.app ?? "").toLowerCase();
        for (const [re, pol] of root.stackRules)
            if (re.test(key))
                return pol;
        return "stack";
    }

    function pruned(list) {
        const seen = ({});
        return list.filter(e => {
            const pol = root.policyFor(e);
            if (pol === "never")
                return true;
            const g = root.gkeyOf(e);
            const n = (seen[g] = (seen[g] ?? 0) + 1);
            if (n <= (pol === "replace" ? 1 : root.stackCap))
                return true;
            e.notification?.dismiss();
            return false;
        });
    }

    readonly property var groups: {
        const out = [];
        const at = ({});
        for (const e of root.history) {
            if (root.policyFor(e) === "never") {
                out.push({ key: "", items: [e] });
                continue;
            }
            const g = root.gkeyOf(e);
            if (g in at) {
                out[at[g]].items.push(e);
                continue;
            }
            at[g] = out.length;
            out.push({ key: g, items: [e] });
        }
        return out;
    }

    property var opened: ({})

    function isOpen(group) {
        return !!root.opened[group?.key ?? ""];
    }
    function toggleGroup(group) {
        const o = Object.assign({}, root.opened);
        if (o[group.key])
            delete o[group.key];
        else
            o[group.key] = true;
        root.opened = o;
    }
    function dismissGroup(group) {
        const keys = (group?.items ?? []).map(e => e.key ?? "");
        for (const h of root.history)
            if (keys.indexOf(h.key) >= 0)
                h.notification?.dismiss();
        root.history = root.history.filter(h => keys.indexOf(h.key) < 0);
        root.stack = 1;
        saveSoon.restart();
        root.closeOsd();
    }

    function dropped(item) {
        return !root.rowFor(item)?.notification;
    }

    property var replayQueue: []

    function replay(n) {
        const take = Math.max(1, Math.min(n || 5, root.history.length));
        root.replayQueue = root.history.slice(0, take).reverse();
        replayTimer.restart();
        root.nextReplay();
    }

    function nextReplay() {
        const q = root.replayQueue.slice();
        const item = q.shift();
        root.replayQueue = q;
        if (!item) {
            replayTimer.stop();
            return;
        }
        NotchState.showOsd("notif", {
            app: item.app,
            title: item.summary,
            body: item.body,
            icon: item.icon,
            image: item.image || item.appIcon,
            action: "",
            urgent: false,
            stack: 1,
            repeats: item.count ?? 1,
            replay: true
        });
    }

    Timer {
        id: replayTimer
        interval: 1700
        repeat: true
        onTriggered: root.nextReplay()
    }

    Timer {
        id: saveSoon
        interval: 400
        onTriggered: root.save()
    }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/notifs.json`
        onLoaded: root.apply(text())
        onLoadFailed: { root.drain(); root.save(); }
    }

    function apply(txt) {
        let saved = [];
        try {
            saved = (JSON.parse(txt).items ?? []).map(i => ({
                id: -1,
                key: i.key ?? "",
                count: i.count ?? 1,
                app: i.app ?? "",
                appIcon: i.appIcon ?? "",
                image: i.image ?? "",
                summary: i.summary ?? "",
                body: i.body ?? "",
                urgency: i.urgency ?? 0,
                resident: false,
                time: new Date(i.time ?? Date.now()),
                notification: null,
                icon: i.icon ?? "notifications"
            }));
        } catch (e) {
            saved = [];
        }
        const live = root.history;
        const merged = live.concat(saved.filter(s => !live.some(e => e.key === s.key)));
        merged.sort((a, b) => b.time - a.time);
        root.history = root.pruned(merged).slice(0, 60);
        root.drain();
    }

    property bool _ready: false
    Component.onCompleted: _ready = true
    function save() {
        if (!_ready)
            return;
        file.setText(JSON.stringify({
            items: root.history.slice(0, 40).map(i => ({
                key: i.key ?? "",
                count: i.count ?? 1,
                app: i.app,
                appIcon: i.appIcon,
                image: i.image.startsWith("image://") ? "" : i.image,
                summary: i.summary,
                body: i.body,
                urgency: i.urgency,
                time: i.time.getTime(),
                icon: i.icon
            }))
        }, null, 2));
    }

    function glyphFor(n) {
        const key = ((n.desktopEntry || n.appName || "") + " " + (n.category || "")).toLowerCase();
        const map = [
            [/discord|element|telegram|signal|whatsapp|matrix|im\./, "chat_bubble"],
            [/mail|geary|evolution|email/, "mail"],
            [/music|mpd|mpv|audacious|player/, "music_note"],
            [/transmission|qbittorrent|deluge|download|transfer/, "download"],
            [/firefox|chromium|chrome|brave|browser/, "public"],
            [/calendar|khal|reminder/, "calendar_month"],
            [/pacman|apt|dnf|update|upgrade/, "system_update"],
            [/battery|power|upower/, "battery_alert"],
            [/device|udev|usb|removable/, "usb"],
            [/screenshot|grim|capture/, "photo_camera"],
            [/network|nm-|wifi|vpn/, "wifi"],
            [/bluetooth|bluez/, "bluetooth"],
            [/error|crash|fail/, "error"],
            [/volume|audio|pipewire/, "volume_up"]
        ];
        for (const [re, glyph] of map)
            if (re.test(key))
                return glyph;
        return n.urgency === NotificationUrgency.Critical ? "priority_high" : "notifications";
    }

    function strip(s) {
        return s.replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/\s+/g, " ").trim();
    }

    function ago(d) {
        const s = Math.max(0, (Date.now() - d.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }
}
