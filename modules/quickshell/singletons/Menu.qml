pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "root:/singletons"

Singleton {
    id: root

    readonly property string sep: "\t"

    Component.onCompleted: {
        DesktopEntries.applications;
        Usage.loaded;
    }

    function short(name) {
        if (!name)
            return "";
        const parts = name.split(".");
        return parts.length > 1 ? parts[parts.length - 1] : name;
    }

    function apps() {
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay)
            .sort((a, b) => Usage.count(b.id) - Usage.count(a.id) || a.name.localeCompare(b.name))
            .map(a => a.id + root.sep + a.name)
            .join("\n");
    }

    function launch(id) {
        const a = DesktopEntries.applications.values.find(x => x.id === id);
        if (!a)
            return "no such app";
        Usage.bump(a.id);
        Quickshell.execDetached(a.runInTerminal ? ["kitty", "-e"].concat(a.command) : a.command);
        return "launched " + a.name;
    }

    function tray() {
        return Tray.items.values
            .map(i => i.id + root.sep + (i.title || i.id))
            .join("\n");
    }

    function trayActivate(id) {
        const i = Tray.items.values.find(x => x.id === id);
        if (!i)
            return "no such item";
        if (i.onlyMenu)
            i.secondaryActivate();
        else
            i.activate();
        return "activated " + id;
    }

    property var levels: []
    property string trayId: ""

    Component {
        id: openerComponent
        QsMenuOpener {}
    }

    function trayOpen(id) {
        trayClose();
        const i = Tray.items.values.find(x => x.id === id);
        if (!i)
            return "no such item";
        if (!i.hasMenu || !i.menu)
            return trayActivate(id);
        trayId = id;
        levels = [openerComponent.createObject(root, { menu: i.menu })];
        return "menu";
    }

    function traySub(index) {
        const top = levels[levels.length - 1];
        const entry = top?.children.values[index];
        if (!entry?.hasChildren)
            return "no such submenu";
        levels = levels.concat([openerComponent.createObject(root, { menu: entry })]);
        return "menu";
    }

    function trayLabel(e) {
        const text = (e.text || "").replace(/_(?!_)/g, "").replace(/&(?!&)/g, "");
        if (e.buttonType === QsMenuButtonType.CheckBox || e.buttonType === QsMenuButtonType.RadioButton)
            return (e.checkState === Qt.Checked ? "[x] " : "[ ] ") + text;
        return e.hasChildren ? text + " >" : text;
    }

    function trayRows() {
        const top = levels[levels.length - 1];
        if (!top)
            return "";
        const entries = top.children.values;
        const rows = [];
        if (levels.length === 1) {
            const item = Tray.items.values.find(x => x.id === root.trayId);
            if (item && !item.onlyMenu)
                rows.push("activate" + root.sep + "activate");
        }
        entries.forEach((e, n) => {
            if (e.isSeparator || !e.enabled || !e.text)
                return;
            rows.push((e.hasChildren ? "sub:" + n : String(n)) + root.sep + trayLabel(e));
        });
        return entries.length ? rows.join("\n") : "";
    }

    function trayTrigger(index) {
        const top = levels[levels.length - 1];
        const entry = top?.children.values[index];
        if (!entry)
            return "no such entry";
        entry.triggered();
        trayClose();
        return "triggered";
    }

    function trayClose() {
        for (const o of levels)
            o.destroy();
        levels = [];
        trayId = "";
        return "closed";
    }

    function players() {
        return NotchState.mediaPlayers
            .map(p => (p.desktopEntry || p.identity) + root.sep
                + `[${root.short(p.identity)}]: "${p.trackTitle || ""}"` + (p.isPlaying ? " ▸" : ""))
            .join("\n");
    }

    function pin(key) {
        Persist.setMediaPin(Persist.mediaPin === key ? "" : key);
        return Persist.mediaPin ? "pinned " + key : "unpinned";
    }

    function sendWhat() {
        const n = LocalSend.outbox.length;
        const parts = [];
        if (LocalSend.compose)
            parts.push("a message");
        if (n)
            parts.push(n === 1 ? LocalSend.name(LocalSend.outbox[0]) : n + " files");
        return parts.join(" and ");
    }

    function sendState() {
        return LocalSend.alive ? sendWhat() : "down";
    }

    function sendPeers() {
        return LocalSend.peers
            .map(p => p.fingerprint + root.sep + `[${p.deviceModel || p.deviceType || "device"}]: "${p.alias}"`)
            .join("\n");
    }

    function sendStage(path) {
        return LocalSend.stage([path]) ? "staged " + LocalSend.outbox.length : "not staged";
    }

    function sendShelf() {
        return LocalSend.stageShelf() ? "staged " + LocalSend.outbox.length : "shelf is empty";
    }

    function sendPaste() {
        LocalSend.paste();
        return "reading the clipboard";
    }

    function sendCompose(text) {
        LocalSend.compose = text;
        return "composed";
    }

    function sendClear() {
        LocalSend.clearOutbox();
        LocalSend.clearCompose();
        return "cleared";
    }

    function sendScan() {
        LocalSend.scan();
        return "scanning";
    }

    function sendTo(fingerprint) {
        const peer = LocalSend.peers.find(x => x.fingerprint === fingerprint);
        if (!peer)
            return "no such device";
        if (!LocalSend.armed)
            return "nothing staged";
        const what = sendWhat();
        const both = LocalSend.compose && LocalSend.outbox.length;
        LocalSend.sendTo(peer);
        if (both)
            LocalSend.sendTo(peer);
        NotchState.showOsd("lsdone", { label: "Sending to " + peer.alias, sub: what + ", waiting for them to accept" });
        return "sending to " + peer.alias;
    }

    function focus(addr) {
        Hyprland.dispatch(`hl.dsp.focus{ window = "address:${addr}" }`);
        return "focused";
    }

    function line(s) {
        return String(s ?? "").replace(/[\t\n\r]+/g, " ").trim();
    }
    function box(on) {
        return on ? "[x] " : "[ ] ";
    }
    function rows(list) {
        return list.map(r => r[0] + root.sep + r[1]).join("\n");
    }

    function controlState() {
        return `vpn ${NotchState.vpnActive ? "on" : "off"}, firewall ${NotchState.firewallActive ? "on" : "off"}`;
    }

    function control() {
        const t = NotchState.toggles;
        const net = NotchState.wired ? NotchState.networkName : (t.wifi ? (NotchState.ssid || "not connected") : "off");
        return root.rows([
            ["wifi", root.box(t.wifi) + "wifi (" + root.line(net) + ")"],
            ["bt", root.box(t.bt) + "bluetooth (" + (t.bt ? NotchState.btConnected + " connected" : "off") + ")"],
            ["dnd", root.box(t.dnd) + "do not disturb"],
            ["night", root.box(t.night) + "night light (" + NightLight.temperature + " K)"],
            ["idleInhibit", root.box(t.idleInhibit) + "keep the screen on"],
            ["nightTemp", "night light temperature >"],
            ["networks", "networks >"],
            ["devices", "bluetooth devices >"],
            ["audio", "audio >"]
        ]);
    }

    function controlToggle(key) {
        if (["wifi", "bt", "dnd", "night", "idleInhibit"].indexOf(key) < 0)
            return "not a toggle";
        NotchState.toggle(key);
        return "toggled " + key;
    }

    function nightTemp(k) {
        if (k > 0)
            NightLight.setTemperature(k);
        return NightLight.temperature + " K";
    }

    function btName(d) {
        const t = Bt.tail(d);
        return root.line(Bt.display(d) + (t ? ` (${t})` : ""));
    }

    function bt() {
        const a = Bluetooth.defaultAdapter;
        if (!a)
            return "";
        const list = [["power", a.enabled ? "turn bluetooth off" : "turn bluetooth on"]];
        if (a.enabled) {
            list.push(["scan", a.discovering ? "stop scanning" : "scan for devices"]);
            list.push(["visible", root.box(a.discoverable) + "visible to other devices"]);
            const all = Bluetooth.devices.values;
            for (const d of all.filter(d => d.paired || d.bonded))
                list.push([d.address, root.box(d.connected) + root.btName(d)
                    + (d.batteryAvailable ? ` (${Math.round((d.battery ?? 0) * 100)}%)` : "")]);
            for (const d of all.filter(d => !(d.paired || d.bonded)))
                list.push([d.address, (d.pairing ? "pairing " : "pair ") + `"${root.btName(d)}"`]);
        }
        return root.rows(list);
    }

    function btPower() {
        NotchState.toggle("bt");
        return "toggled";
    }

    function btScan() {
        const a = Bluetooth.defaultAdapter;
        if (!a)
            return "no adapter";
        a.discovering = !a.discovering;
        return a.discovering ? "scanning" : "stopped";
    }

    function btVisible() {
        const a = Bluetooth.defaultAdapter;
        if (!a)
            return "no adapter";
        if (!a.enabled)
            return "bluetooth is off";
        a.discoverableTimeout = 180;
        a.pairable = true;
        a.discoverable = !a.discoverable;
        return a.discoverable ? "visible" : "hidden";
    }

    function btActions(addr) {
        const d = Bluetooth.devices.values.find(x => x.address === addr);
        if (!d)
            return "";
        if (!(d.paired || d.bonded))
            return root.rows([[d.pairing ? "cancel" : "pair", d.pairing ? "cancel pairing" : "pair"]]);
        return root.rows([
            [d.connected ? "disconnect" : "connect", d.connected ? "disconnect" : "connect"],
            ["trust", root.box(d.trusted) + "trusted"],
            ["forget", "forget this device"]
        ]);
    }

    function btAct(addr, what) {
        const d = Bluetooth.devices.values.find(x => x.address === addr);
        if (!d)
            return "no such device";
        if (what === "pair")
            d.pair();
        else if (what === "cancel")
            d.cancelPair();
        else if (what === "connect")
            d.connect();
        else if (what === "disconnect")
            d.disconnect();
        else if (what === "trust")
            d.trusted = !d.trusted;
        else if (what === "forget")
            d.forget();
        else
            return "no such action";
        return what;
    }

    function btStopScan() {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.discovering = false;
        return "stopped";
    }

    function btDevice(addr) {
        const d = Bluetooth.devices.values.find(x => x.address === addr);
        if (!d)
            return "no such device";
        if (!(d.paired || d.bonded)) {
            d.pair();
            return "pairing";
        }
        if (d.connected)
            d.disconnect();
        else
            d.connect();
        return "toggled";
    }

    readonly property var audioNodes: Pipewire.nodes.values.filter(n => n.audio)
    PwObjectTracker {
        objects: root.audioNodes
    }

    function nodeName(n) {
        return root.line(n.description || n.nickname || n.name);
    }
    function level(n) {
        return Math.round((n?.audio?.volume ?? 0) * 100) + "%" + (n?.audio?.muted ? " muted" : "");
    }

    function audio() {
        const list = [["volume", "volume " + root.level(Audio.sink)], ["mic", "microphone " + root.level(Audio.micNode)]];
        const devs = root.audioNodes.filter(n => !n.isStream);
        for (const n of devs.filter(n => n.isSink))
            list.push(["dev:" + n.id, root.box(Pipewire.defaultAudioSink === n) + "output: " + root.nodeName(n)]);
        for (const n of devs.filter(n => !n.isSink))
            list.push(["dev:" + n.id, root.box(Pipewire.defaultAudioSource === n) + "input: " + root.nodeName(n)]);
        for (const n of root.audioNodes.filter(n => n.isStream && n.isSink))
            list.push(["stream:" + n.id, `[${root.line(Apps.nameFor(n))}]: ` + root.level(n)]);
        return root.rows(list);
    }

    function audioNode(key) {
        if (key === "volume")
            return Audio.sink;
        if (key === "mic")
            return Audio.micNode;
        const id = parseInt(key.split(":")[1]);
        return Pipewire.nodes.values.find(n => n.id === id) ?? null;
    }

    function audioDefault(key) {
        const n = root.audioNode(key);
        if (!n || n.isStream)
            return "not a device";
        if (n.isSink)
            Pipewire.preferredDefaultAudioSink = n;
        else
            Pipewire.preferredDefaultAudioSource = n;
        return "default " + root.nodeName(n);
    }

    function audioLevel(key, v) {
        const n = root.audioNode(key);
        if (!n?.audio)
            return "no such node";
        n.audio.volume = Math.max(0, Math.min(100, v)) / 100;
        return root.level(n);
    }

    function audioMute(key) {
        const n = root.audioNode(key);
        if (!n?.audio)
            return "no such node";
        n.audio.muted = !n.audio.muted;
        return root.level(n);
    }

    function notifKeys() {
        const seen = ({});
        return Notifs.history.map(h => {
            const base = Notifs.hashOf((h.key ?? "") + "\u0000" + (h.time?.getTime?.() ?? 0));
            seen[base] = (seen[base] ?? 0) + 1;
            return seen[base] > 1 ? base + "-" + seen[base] : base;
        });
    }
    function notifRow(key) {
        const i = root.notifKeys().indexOf(key);
        return i >= 0 ? Notifs.history[i] : null;
    }

    function notifs() {
        const list = [["dnd", root.box(NotchState.dnd) + "do not disturb"]];
        if (Notifs.history.length)
            list.push(["clear", "clear all"]);
        const keys = root.notifKeys();
        Notifs.history.forEach((h, i) => {
            const body = root.line(h.body);
            list.push([keys[i], `[${root.line(h.app)}]: "${root.line(h.summary)}"`
                + (body ? " " + (body.length > 70 ? body.slice(0, 69) + "…" : body) : "")
                + (h.count > 1 ? ` (x${h.count})` : "") + " " + Notifs.ago(h.time)]);
        });
        return root.rows(list);
    }

    function notifActions(key) {
        const h = root.notifRow(key);
        if (!h)
            return "";
        const list = [["open", "open"]];
        Notifs.buttons(h).forEach((a, i) => list.push(["a:" + i, root.line(a.text)]));
        list.push(["dismiss", "dismiss"]);
        return root.rows(list);
    }

    function notifAct(key, what) {
        const h = root.notifRow(key);
        if (!h)
            return "gone";
        if (what === "dismiss") {
            Notifs.dismiss(h);
            return "dismissed";
        }
        if (what === "open") {
            Notifs.invokePrimary(h);
            return "opened";
        }
        const a = Notifs.buttons(h)[parseInt(what.slice(2))];
        if (!a)
            return "no such action";
        Notifs.invokeAction(h, a);
        return "invoked";
    }

    function notifClear() {
        Notifs.clearAll();
        return "cleared";
    }

    function calState() {
        if (!Agenda.connected)
            return "not connected, run gcal sync";
        return Agenda.syncing ? "syncing" : (Agenda.writing ? "saving" : "google calendar");
    }

    function calEvent(id) {
        return Agenda.events.find(e => e.id === id) ?? null;
    }

    function cal() {
        const now = Date.now();
        const list = [["add", "add an event"], ["sync", "sync now"]];
        Agenda.events
            .filter(e => new Date(e.end).getTime() > now)
            .sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime())
            .slice(0, 40)
            .forEach(e => list.push([e.id, Qt.formatDateTime(new Date(e.start), "ddd d MMM") + " "
                + Agenda.span(e) + ` "${root.line(e.title)}"` + (e.location ? " @ " + root.line(e.location) : "")]));
        return root.rows(list);
    }

    function calActions(id) {
        const e = root.calEvent(id);
        if (!e)
            return "";
        const list = [];
        if (e.meetLink)
            list.push(["join", "join the call"]);
        if (e.link)
            list.push(["open", "open in the browser"]);
        list.push(["delete", "delete"]);
        return root.rows(list);
    }

    function calAct(id, what) {
        const e = root.calEvent(id);
        if (!e)
            return "gone";
        if (what === "join")
            Agenda.launch(e.meetLink);
        else if (what === "open")
            Agenda.launch(e.link);
        else if (what === "delete")
            Agenda.remove(e);
        else
            return "no such action";
        return what;
    }

    function calAdd(text) {
        Agenda.add(text);
        return "adding";
    }

    function calSync() {
        Agenda.refresh();
        return "syncing";
    }

    function netRefresh() {
        Net.readDns();
        return "reading";
    }

    function net() {
        const list = [["stats", "show rates and results"], ["ping", "run a ping"], ["speed", "run a speed test"]];
        const current = Net.dnsPresets.find(p => p.servers !== "" && p.servers === Net.dns) ?? Net.dnsPresets[0];
        for (const p of Net.dnsPresets)
            list.push(["dns:" + p.label, root.box(p === current) + "dns " + p.label.toLowerCase()
                + (p.servers ? ` (${p.servers.split(",")[0]})` : "")]);
        if (NotchState.ssid)
            list.push(["qr", `share "${root.line(NotchState.ssid)}" as a qr code`]);
        return root.rows(list);
    }

    function netAct(what) {
        if (what === "ping")
            Net.runPing();
        else if (what === "speed")
            Net.runSpeed();
        else if (what === "qr")
            Net.makeQr(NotchState.ssid);
        else if (what.startsWith("dns:")) {
            const p = Net.dnsPresets.find(x => "dns:" + x.label === what);
            if (!p)
                return "no such preset";
            Net.setDns(p.label, p.servers);
        } else
            return "no such action";
        return what;
    }

    function weather() {
        const list = [["forecast", "show the forecast"], ["refresh", "refresh now"],
            ["place", "change the location" + (Config.weatherPlace ? ` (${root.line(Config.weatherPlace)})` : "")]];
        if (Weather.configured)
            list.push(["forget", "forget the location"]);
        return root.rows(list);
    }

    function weatherAct(what) {
        if (what === "refresh")
            Weather.refresh();
        else if (what === "forget")
            Weather.forget();
        else
            return "no such action";
        return what;
    }

    function weatherSearch(q) {
        Weather.search(q);
        return "searching";
    }

    function weatherSearching() {
        return Weather.searching ? "yes" : "no";
    }

    function weatherPlaces() {
        return Weather.places
            .map((p, i) => i + root.sep + root.line(p.name + (p.detail ? ", " + p.detail : "")))
            .join("\n");
    }

    function weatherPick(i) {
        const p = Weather.places[i];
        if (!p)
            return "no such place";
        Weather.pick(p);
        return "set " + p.name;
    }
}
