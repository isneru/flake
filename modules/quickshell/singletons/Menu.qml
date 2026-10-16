pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Mpris
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

    function open(id, order) {
        const hex = s => String(s ?? "").toLowerCase().replace(/^0x/, "");
        const mine = Hyprland.toplevels.values
            .filter(t => DesktopEntries.heuristicLookup(t.wayland?.appId ?? "")?.id === id)
            .map(t => hex(t.address));
        const addr = order.split(" ").find(x => x && mine.includes(hex(x)));
        if (!addr)
            return launch(id);
        Usage.bump(id);
        return focus(addr);
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
        return BareState.mediaPlayers
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
        BareState.showOsd("lsdone", { label: "Sending to " + peer.alias, sub: what + ", waiting for them to accept" });
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
        return `vpn ${BareState.vpnActive ? "on" : "off"}, firewall ${BareState.firewallActive ? "on" : "off"}`;
    }

    function control() {
        const t = BareState.toggles;
        const net = BareState.wired ? BareState.networkName : (t.wifi ? (BareState.ssid || "not connected") : "off");
        return root.rows([
            ["wifi", root.box(t.wifi) + "wifi (" + root.line(net) + ")"],
            ["bt", root.box(t.bt) + "bluetooth (" + (t.bt ? BareState.btConnected + " connected" : "off") + ")"],
            ["dnd", root.box(t.dnd) + "do not disturb"],
            ["night", root.box(t.night) + "night light (" + NightLight.temperature + " K)"],
            ["idleInhibit", root.box(t.idleInhibit) + "keep the screen on"],
            ["nightTemp", "night light temperature >"],
            ["networks", "wifi >"],
            ["devices", "bluetooth >"],
            ["audio", "audio >"]
        ]);
    }

    function controlToggle(key) {
        if (["wifi", "bt", "dnd", "night", "idleInhibit"].indexOf(key) < 0)
            return "not a toggle";
        BareState.toggle(key);
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
        const list = [["power", root.box(a.enabled) + "powered"]];
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
        BareState.toggle("bt");
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

    function clock(sec) {
        const t = Math.max(0, Math.floor(sec || 0));
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0");
    }

    function mediaState() {
        const p = BareState.mediaPlayer;
        if (!p)
            return "nothing is playing";
        const what = p.trackTitle ? `"${root.line(p.trackTitle)}"` + (p.trackArtist ? " - " + root.line(p.trackArtist) : "") : "no track";
        const at = p.length > 0 ? `, ${root.clock(p.position)}/${root.clock(p.length)}` : "";
        return `${root.short(p.identity)}: ${p.isPlaying ? "playing" : "paused"} ${what}${at}`;
    }

    function media() {
        const p = BareState.mediaPlayer;
        const list = [];
        if (p) {
            if (p.canTogglePlaying)
                list.push(["toggle", p.isPlaying ? "pause" : "play"]);
            if (p.canGoNext)
                list.push(["next", "next"]);
            if (p.canGoPrevious)
                list.push(["previous", "previous"]);
            if (p.canSeek && p.length > 0)
                list.push(["seek", "seek >"]);
            if (p.shuffleSupported)
                list.push(["shuffle", root.box(p.shuffle) + "shuffle"]);
            if (p.loopSupported)
                list.push(["loop", "loop: " + (p.loopState === MprisLoopState.Track ? "track" : (p.loopState === MprisLoopState.Playlist ? "playlist" : "off"))]);
        }
        if (BareState.mediaPlayers.length)
            list.push(["players", "players >"]);
        return root.rows(list);
    }

    function mediaAct(what) {
        const p = BareState.mediaPlayer;
        if (!p)
            return "no player";
        if (what === "toggle" && p.canTogglePlaying)
            p.togglePlaying();
        else if (what === "next" && p.canGoNext)
            p.next();
        else if (what === "previous" && p.canGoPrevious)
            p.previous();
        else if (what === "shuffle" && p.shuffleSupported)
            p.shuffle = !p.shuffle;
        else if (what === "loop" && p.loopSupported)
            p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                : (p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
        else
            return "not available";
        return what;
    }

    function mediaSeek(spec) {
        const p = BareState.mediaPlayer;
        if (!p?.canSeek || !(p.length > 0))
            return "cannot seek";
        const s = String(spec).trim();
        let to;
        let m;
        if ((m = /^(back|ahead):(\d+)$/.exec(s)))
            to = p.position + (m[1] === "back" ? -1 : 1) * parseInt(m[2]);
        else if ((m = /^(\d+(?:\.\d+)?)%$/.exec(s)))
            to = p.length * parseFloat(m[1]) / 100;
        else if ((m = /^(\d+):(\d{1,2})$/.exec(s)))
            to = parseInt(m[1]) * 60 + parseInt(m[2]);
        else if ((m = /^(\d+)s?$/.exec(s)))
            to = parseInt(m[1]);
        else
            return "not understood";
        p.position = Math.max(0, Math.min(p.length - 1, to));
        return root.clock(p.position);
    }

    function monitor(name) {
        return Hyprland.monitors.values.find(m => m.name === name) ?? null;
    }

    function displayLabel(name) {
        const g = root.monitor(name)?.lastIpcObject;
        if (!g)
            return Display.ruleFor(name).mirror ? "mirroring " + Display.ruleFor(name).mirror : "disabled";
        const vrr = Display.ruleFor(name).vrr ?? "0";
        return `${g.width ?? 0}x${g.height ?? 0} @ ${Math.round(g.refreshRate ?? 0)} Hz, scale ${(g.scale ?? 1).toFixed(2)}, `
            + `rotated ${90 * ((g.transform ?? 0) % 4)}°, vrr ${vrr === "1" ? "on" : (vrr === "2" ? "fullscreen" : "off")}`
            + (Display.ruleFor(name).mirror ? ", mirroring " + Display.ruleFor(name).mirror : "");
    }

    function screens() {
        const names = Hyprland.monitors.values.map(m => m.name);
        for (const n of Object.keys(Display.rules))
            if (((Display.ruleFor(n).disabled ?? "") === "1" || Display.ruleFor(n).mirror) && names.indexOf(n) < 0)
                names.push(n);
        return names;
    }

    function mirrored() {
        const others = root.screens().filter(n => n !== "eDP-1");
        return others.length > 0 && others.every(n => Display.ruleFor(n).mirror === "eDP-1");
    }

    function displays() {
        Hyprland.refreshMonitors();
        const names = root.screens();
        const list = names.map(n => [n, `${n}: ${root.displayLabel(n)}`]);
        if (names.length > 1)
            list.unshift(["mode", `mode: ${root.mirrored() ? "mirror" : "extend"} >`]);
        return root.rows(list);
    }

    function displayModes() {
        const on = root.mirrored();
        return root.rows([["extend", root.box(!on) + "extend"], ["mirror", root.box(on) + "mirror eDP-1"]]);
    }

    function displayMode(mode) {
        if (mode === "mirror")
            Display.mirrorAll(root.screens(), "eDP-1");
        else
            Display.mirrorAll(Object.keys(Display.rules), "");
        return "set";
    }

    function display(name) {
        return `${name} [${root.displayLabel(name)}]`;
    }

    function displayActions(name) {
        const on = (Display.ruleFor(name).disabled ?? "") !== "1";
        const list = [];
        if (on && root.monitor(name)) {
            list.push(["mode", "resolution and refresh >"], ["scale", "scale >"], ["transform", "rotation >"],
                ["vrr", "variable refresh >"]);
            if (Hyprland.monitors.values.length > 1)
                list.push(["mirror", "mirror >"]);
        }
        list.push(["disabled", root.box(on) + "enabled"], ["reset", "reset to defaults"]);
        return root.rows(list);
    }

    function displayOptions(name, key) {
        const g = root.monitor(name)?.lastIpcObject ?? {};
        const rule = Display.ruleFor(name);
        let opts = [];
        if (key === "mode") {
            const here = `${g.width}x${g.height}@${Math.round(g.refreshRate ?? 0)}`;
            opts = (g.availableModes ?? []).map(m => m.replace("Hz", ""))
                .filter((m, i, all) => all.indexOf(m) === i)
                .map(m => [m, m.replace(/@(\d+)\.\d+$/, (_, hz) => ` @ ${hz} Hz`), m.startsWith(here)]);
        } else if (key === "scale") {
            const now = parseFloat((g.scale ?? 1).toFixed(2));
            opts = ["1", "1.25", "1.5", "1.75", "2"].map(v => [v, v, parseFloat(v) === now]);
        } else if (key === "transform") {
            opts = ["0", "1", "2", "3"].map(v => [v, 90 * parseInt(v) + "°", parseInt(v) === (g.transform ?? 0) % 4]);
        } else if (key === "vrr") {
            const now = rule.vrr ?? "0";
            opts = [["0", "off"], ["1", "on"], ["2", "fullscreen only"]].map(o => [o[0], o[1], o[0] === now]);
        } else if (key === "mirror") {
            const now = rule.mirror ?? "";
            opts = [["", "none"]].concat(Hyprland.monitors.values.filter(m => m.name !== name).map(m => [m.name, m.name]))
                .map(o => [o[0] || "none", o[1], o[0] === now]);
        }
        return root.rows(opts.map(o => [o[0], root.box(o[2]) + o[1]]));
    }

    function displaySet(name, key, value) {
        if (key === "reset") {
            Display.reset(name);
            return "reset";
        }
        if (key === "disabled")
            value = (Display.ruleFor(name).disabled ?? "") === "1" ? "" : "1";
        if (key === "mirror" && value === "none")
            value = "";
        return Display.set(name, key, value) ? "set" : "refused, it is the last screen on";
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
        if (BareState.ssid)
            list.push(["qr", `share "${root.line(BareState.ssid)}" as a qr code`]);
        return root.rows(list);
    }

    function netAct(what) {
        if (what === "ping")
            Net.runPing();
        else if (what === "speed")
            Net.runSpeed();
        else if (what === "qr")
            Net.makeQr(BareState.ssid);
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
            ["place", "change the location" + (Weather.place ? ` (${root.line(Weather.place)})` : "")]];
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
