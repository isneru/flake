pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "root:/singletons"

Singleton {
    id: root

    property string mode: "idle"
    property string panel: "home"
    property var navStack: []

    readonly property bool isIdle: mode === "idle"
    readonly property bool isPeek: mode === "peek"
    readonly property bool isOsd: mode === "osd"
    readonly property bool isExpanded: mode === "expanded"

    property string osdKind: ""
    property var osdData: ({})
    readonly property var osd: specFor(osdKind)

    readonly property bool dnd: Persist.dnd
    readonly property bool idleInhibit: Persist.idleInhibit
    property bool vpnActive: false
    property bool firewallActive: false

    readonly property var btAdapter: Bluetooth.defaultAdapter

    readonly property var toggles: ({
        wifi: Networking.wifiEnabled,
        bt: btAdapter?.enabled ?? false,
        dnd: dnd,
        night: NightLight.enabled,
        vpn: vpnActive,
        firewall: firewallActive,
        idleInhibit: idleInhibit
    })

    property bool btRestored: false
    onBtAdapterChanged: restoreBt()
    Component.onCompleted: restoreBt()
    Connections {
        target: Persist
        function onLoadedChanged() { root.restoreBt(); }
    }
    function restoreBt() {
        if (btRestored || !Persist.loaded || !btAdapter)
            return;
        btRestored = true;
        btAdapter.enabled = Persist.bt;
    }

    readonly property string ssid: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi)
                for (const n of d.networks.values)
                    if (n.connected)
                        return n.name;
        return "";
    }

    readonly property var wiredDevice: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wired && d.connected)
                return d;
        return null;
    }
    readonly property bool wired: ssid === "" && wiredDevice !== null
    readonly property string networkName: ssid || (wired ? (wiredDevice.network?.name || wiredDevice.name) : "")

    readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length

    readonly property int volume: Audio.volume
    readonly property int brightness: Brightness.percent
    readonly property int micGain: Audio.micGain
    property bool recording: false
    property int recElapsed: 0
    property bool micInUse: false

    Connections {
        target: Audio

        function onVolumeChanged() { if (root.osdReady) root.showOsd("vol"); }
        function onMutedChanged() { if (root.osdReady) root.showOsd("vol"); }
    }

    property bool osdReady: false
    Timer {
        interval: 4000
        running: true
        onTriggered: root.osdReady = true
    }

    function mins(s) {
        if (!(s > 0))
            return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        return h > 0 ? h + "h " + m + "m" : m + " min";
    }

    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery) ?? UPower.displayDevice
    property bool lowFired: false

    Connections {
        target: root.battery
        function onStateChanged() {
            if (!root.osdReady || !root.battery)
                return;
            const pct = Math.round(root.battery.percentage * 100);
            if (root.battery.state === UPowerDeviceState.Charging) {
                const to = root.mins(root.battery.timeToFull);
                root.showOsd("charge", { pct: pct, sub: pct + "%" + (to ? " - " + to + " to full" : "") });
            } else if (root.battery.state === UPowerDeviceState.Discharging) {
                const left = root.mins(root.battery.timeToEmpty);
                root.showOsd("unplug", { pct: pct, sub: pct + "%" + (left ? " - " + left + " left" : "") });
            }
            root.checkLow();
        }
        function onPercentageChanged() { root.checkLow(); }
    }

    function checkLow() {
        if (!battery)
            return;
        const pct = Math.round(battery.percentage * 100);
        const draining = battery.state === UPowerDeviceState.Discharging;

        if (draining && pct <= 15 && !lowFired) {
            lowFired = true;
            if (osdReady) {
                const left = mins(battery.timeToEmpty);
                showOsd("low", { pct: pct, sub: pct + "%" + (left ? " - " + left + " left" : "") });
            }
        } else if (!draining || pct > 20) {
            lowFired = false;
        }
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (!root.osdReady || !modelData.connected)
                    return;
                const b = modelData.batteryAvailable ? " - " + Math.round(modelData.battery * 100) + "%" : "";
                root.showOsd("bt", {
                    name: modelData.name || modelData.deviceName || modelData.address,
                    sub: "connected" + b
                });
            }
        }
    }

    readonly property var mediaPriority: ["mpd", "qutebrowser"]

    function playerRank(p) {
        const key = ((p?.desktopEntry ?? "") + " " + (p?.identity ?? "")).toLowerCase();
        const i = root.mediaPriority.findIndex(n => key.includes(n));
        return i < 0 ? root.mediaPriority.length : i;
    }

    readonly property var mediaPlayers: Mpris.players.values

    function playerId(p) {
        return ((p?.desktopEntry || p?.identity) ?? "").toLowerCase();
    }
    readonly property string mediaPin: Persist.mediaPin
    function pinMedia(p) {
        const id = root.playerId(p);
        Persist.setMediaPin(root.mediaPin === id ? "" : id);
    }

    property var playOrder: ({})
    property int playSerial: 0

    function syncPlayOrder() {
        const next = {};
        let serial = root.playSerial;
        for (const p of root.mediaPlayers) {
            if (!p.isPlaying)
                continue;
            next[p.dbusName] = root.playOrder[p.dbusName] ?? ++serial;
        }
        root.playSerial = serial;
        root.playOrder = next;
    }
    onMediaPlayersChanged: syncPlayOrder()

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { root.syncPlayOrder(); }
        }
    }

    readonly property var playingPlayers: {
        const l = root.mediaPlayers.filter(p => p.isPlaying);
        l.sort((a, b) => (root.playOrder[a.dbusName] ?? 0) - (root.playOrder[b.dbusName] ?? 0));
        return l;
    }

    function playerTier(p) {
        if (p.trackTitle || p.trackArtist)
            return 0;
        return (p.canTogglePlaying || p.canPlay) ? 1 : 2;
    }

    readonly property var mediaPlayer: {
        const ps = root.mediaPlayers;
        if (!ps.length)
            return null;

        const pinned = root.mediaPin ? ps.find(p => root.playerId(p) === root.mediaPin) : null;
        if (pinned)
            return pinned;
        if (root.playingPlayers.length)
            return root.playingPlayers[0];

        const rest = ps.slice();
        rest.sort((a, b) => (root.playerTier(a) - root.playerTier(b))
            || (root.playerRank(a) - root.playerRank(b))
            || (a.identity ?? "").localeCompare(b.identity ?? ""));
        return rest[0];
    }

    readonly property var mediaToggle: playingPlayers[0] ?? mediaPlayer

    property string trackKey: ""
    Timer {
        id: trackOsd
        interval: 400
        onTriggered: {
            const p = root.mediaPlayer;
            if (!p?.trackTitle)
                return;
            const key = p.dbusName + " " + p.trackTitle;
            if (key === root.trackKey)
                return;
            root.trackKey = key;
            root.showOsd("track", {
                title: p.trackTitle,
                artist: p.trackArtist ?? "",
                artUrl: p.trackArtUrl ?? ""
            });
        }
    }
    Connections {
        target: root.mediaPlayer
        function onTrackTitleChanged() { if (root.osdReady) trackOsd.restart(); }
        function onTrackArtistChanged() { if (root.osdReady) trackOsd.restart(); }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") {
                Hyprland.refreshToplevels();
                return;
            }

            if (!root.osdReady || event.name !== "activelayout")
                return;
            const parts = event.data.split(",");
            root.showOsd("caps", { label: "Keyboard layout", sub: parts[0] ?? "", right: parts[1] ?? "" });
        }
    }

    readonly property var micStreams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio)
    PwObjectTracker { objects: root.micStreams }

    onMicStreamsChanged: micInUse = micStreams.length > 0

    function saveShot() {
        const p = osdData.path;
        if (p)
            Quickshell.execDetached(["screenshot", "--save", p]);
    }

    function startRecording() {
        recElapsed = 0;
        recording = true;
        showOsd("rec");
    }
    function stopRecording() {
        recording = false;
        if (osdKind === "rec")
            close();
    }

    Connections {
        target: Shelf
        function onDropSummary(label, sub) { root.showOsd("shelf", { label: label, sub: sub }); }
    }

    function setVolume(v) {
        Audio.setVolume(v);
    }
    function setMicGain(v) {
        Audio.setMicGain(v);
    }
    function toggleMicMute() {
        Audio.toggleMicMute();
        showOsd("mic");
    }
    function setBrightness(v) {
        Brightness.set(v);
    }
    function stepBrightness(delta) {
        Brightness.step(delta);
        showOsd("bri");
    }

    function toggle(key) {
        switch (key) {
        case "wifi":
            Networking.wifiEnabled = !Networking.wifiEnabled;
            break;
        case "bt":
            if (btAdapter) {
                const on = !btAdapter.enabled;
                btAdapter.enabled = on;
                Persist.setBt(on);
            }
            break;
        case "dnd":
            Persist.setDnd(!dnd);
            showOsd("dnd");
            break;
        case "night":
            NightLight.setEnabled(!NightLight.enabled);
            showOsd("night");
            break;
        case "idleInhibit":
            Persist.setIdleInhibit(!idleInhibit);
            break;
        case "vpn":
            if (!vpnAction.running)
                vpnAction.running = true;
            break;
        }
    }

    readonly property string vpnScript: 'pick() { nmcli -t -f TYPE,NAME connection show ${1:+--active} | '
        + 'awk -F: \'$1=="vpn"||$1=="wireguard"{sub(/^[^:]*:/,""); gsub(/\\\\:/,":"); print; exit}\'; }; '
        + 'on=$(pick active); '
        + 'if [ -n "$on" ]; then nmcli connection down id "$on" >/dev/null 2>&1 && printf "down\\t%s" "$on" || printf "fail\\t%s" "$on"; '
        + 'else off=$(pick); [ -n "$off" ] || { printf "none\\t"; exit 0; }; '
        + 'nmcli connection up id "$off" >/dev/null 2>&1 && printf "up\\t%s" "$off" || printf "fail\\t%s" "$off"; fi'

    Process {
        id: vpnAction
        command: ["sh", "-c", root.vpnScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\t");
                const name = parts[1] ?? "";
                const say = ({
                    up: { label: "VPN connected", sub: name, color: Theme.success },
                    down: { label: "VPN disconnected", sub: name, color: Theme.accent },
                    none: { label: "No VPN configured", sub: "add a profile with nmcli", color: Theme.warning },
                    fail: { label: "VPN unchanged", sub: name, color: Theme.error }
                })[parts[0]] ?? { label: "VPN unchanged", sub: "", color: Theme.error };
                root.showOsd("msg", Object.assign({ icon: "vpn_key" }, say));
                vpnProbe.running = true;
            }
        }
    }

    Process {
        id: vpnProbe
        command: ["nmcli", "-t", "-f", "TYPE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: root.vpnActive = /^(vpn|wireguard)$/m.test(text)
        }
    }
    Process {
        id: fwProbe
        running: true
        command: ["systemctl", "is-active", "--quiet", "firewall"]
        onExited: code => root.firewallActive = code === 0
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            vpnProbe.running = true;
        }
    }

    property bool dropTarget: false

    readonly property int pad: 140
    readonly property bool split: Config.pillStyle === "split" && mode === "idle" && !dropTarget
    readonly property bool floating: Config.pillStyle !== "notch"
    readonly property int topMargin: floating ? 10 : 0

    readonly property bool agendaChip: Agenda.flash && Config.pillStyle !== "split"

    readonly property int peekExceptions:
        (Audio.muted ? 1 : 0) + (toggles.dnd ? 1 : 0) + (NightLight.enabled ? 1 : 0) + (micInUse ? 1 : 0)

    readonly property int peekSpaces: Hyprland.workspaces.values.filter(w => w.id > 0).length

    readonly property int peekW:
        245 + Math.max(0, peekSpaces - 1) * 11 + peekExceptions * 11

    readonly property int surfaceW: {
        if (isExpanded) return 840;
        if (dropTarget) return 330;
        if (isOsd) return osd.w;
        if (isPeek) return peekW;
        if (Config.pillStyle === "split") return 340;
        return Activities.active?.w ?? 196;
    }
    readonly property int collapsedH: 34
    readonly property int surfaceH: {
        if (isExpanded) return 540;
        if (dropTarget) return 66;
        if (isOsd) return osd.h;
        if (isPeek) return 52;
        return collapsedH;
    }

    readonly property var focusedWs: Hyprland.focusedWorkspace

    readonly property bool fullscreen: {
        const ws = focusedWs;
        if (!ws || !ws.hasFullscreen)
            return false;
        for (const t of ws.toplevels.values)
            if (((t.lastIpcObject?.fullscreen ?? 0) & 2) !== 0)
                return true;
        return false;
    }
    readonly property bool hidden: fullscreen && (isIdle || isPeek)

    readonly property int reserved: topMargin + collapsedH

    readonly property int radiusTop: {
        if (Config.pillStyle === "notch") return 0;
        if (isExpanded) return Theme.rExpanded;
        if (dropTarget) return Theme.rOsd;
        return isOsd ? Theme.rOsd : (isPeek ? Theme.rPeek : Theme.rCollapsed);
    }
    readonly property int radiusBottom: isExpanded ? Theme.rExpanded : ((dropTarget || isOsd) ? Theme.rOsd : (isPeek ? Theme.rPeek : Theme.rCollapsed))
    readonly property color surfaceColor: split ? "transparent" : (Config.pillStyle === "notch" && isIdle ? Theme.notchSolid : Theme.notchGlass)

    function peek() {
        if (mode === "idle")
            mode = "peek";
    }
    function unpeek() {
        if (mode === "peek")
            mode = "idle";
    }
    readonly property bool modal: Auth.pending || Screencast.pending || LocalSend.ask !== null
    readonly property string modalPanel: Auth.pending ? "auth" : (Screencast.pending ? "share" : "send")

    function close() {
        if (modal)
            return;
        mode = "idle";
        osdKind = "";
        navStack = [];

        Notifs.stack = 1;
    }
    function open(p) {
        if (Mode.bare || (modal && p !== modalPanel))
            return;
        const subs = ["launcher", "calc", "clip", "shelf", "send", "timer", "weather", "net", "qr", "wall", "theme", "monitor", "display", "power", "audio", "wifi", "bt", "shell", "keys"];
        navStack = subs.includes(p) ? (navStack.length ? navStack : [panel === p ? "tools" : panel]) : [];
        panel = p;
        mode = "expanded";
        osdTimer.stop();
    }
    function back() {
        if (modal)
            return;
        const st = navStack.slice();
        panel = st.pop() ?? "home";
        navStack = st;
    }

    function activate() {
        if (mode === "expanded" || modal || Mode.bare)
            return;
        const map = ({
            vol: "audio", mic: "audio", bri: "display", charge: "power", unplug: "power", low: "power", bt: "bt",
            track: "media",
            dl: "notif", dnd: "notif", notif: "notif", night: "control", caps: "control",
            shelf: "shelf", qrres: "qr", lsdone: "send"
        });
        const target = mode === "osd" ? (map[osdKind] ?? "home") : (Activities.active?.panel ?? "home");
        navStack = target === "home" ? [] : ["home"];
        panel = target;
        mode = "expanded";
        osdTimer.stop();
    }

    function showOsd(kind, data) {
        if (mode === "expanded")
            return;
        osdData = data ?? ({});
        osdKind = kind;
        mode = "osd";
        osdTimer.restart();
        if (osd.persist)
            osdTimer.stop();
    }

    Timer {
        id: osdTimer
        interval: root.osd.dwell
        onTriggered: if (root.mode === "osd") root.close()
    }

    property bool osdHovered: false
    onOsdHoveredChanged: {
        if (mode !== "osd" || osd.persist)
            return;
        if (osdHovered)
            osdTimer.stop();
        else
            osdTimer.restart();
    }

    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.recElapsed++
    }

    function fmt(s) {
        return Math.floor(s / 60) + ":" + String(Math.floor(s % 60)).padStart(2, "0");
    }

    function specFor(kind) {
        const d = osdData;
        const S = {
            vol: { icon: (Audio.muted || volume === 0) ? "volume_off" : "volume_up", label: "Volume", sub: d.sink ?? Audio.sinkName, pct: volume, color: Theme.accent, w: 340, h: 52, bar: true },
            bri: { icon: "brightness_6", label: "Brightness", sub: d.output ?? Brightness.device, pct: brightness, color: Theme.t1, w: 340, h: 52, bar: true },
            charge: { icon: "battery_charging_full", label: "Charging", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.success, w: 340, h: 52, bar: true },
            unplug: { icon: "power_off", label: "On battery", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.accent, w: 340, h: 52, bar: true },
            low: { icon: "battery_alert", label: "Battery low", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.warning, w: 340, h: 52, bar: true },
            bt: { icon: "bluetooth_connected", label: d.name ?? "Device", sub: d.sub ?? "connected", color: Theme.accent, w: 330, h: 48 },
            mic: { icon: Audio.micMuted ? "mic_off" : "mic", label: Audio.micMuted ? "Microphone muted" : "Microphone on", sub: Audio.sourceName, color: Audio.micMuted ? Theme.error : Theme.success, w: 340, h: 48 },
            msg: { icon: d.icon ?? "info", label: d.label ?? "", sub: d.sub ?? "", color: d.color ?? Theme.accent, w: 340, h: 48 },
            shot: { icon: "", label: d.saved ? "Saved to ~/pictures/screenshots" : "Copied to clipboard", sub: "", color: Theme.accent, w: 410, h: 62, thumb: true, save: !d.saved, dwell: 3600 },
            rec: { icon: "screen_record", label: "Recording", sub: d.sub ?? "", right: fmt(recElapsed), color: Theme.error, w: 320, h: 48 },
            caps: { icon: "keyboard_capslock", label: d.label ?? "Caps Lock", sub: d.sub ?? "", right: d.right ?? "ON", color: Theme.accent, w: 300, h: 46 },
            track: { icon: "", label: d.title ?? "", sub: d.artist ?? "", color: Theme.accent, w: 360, h: 60, art: true, eq: true },

            notif: { color: d.urgent ? Theme.error : Theme.accent, w: 410, h: 80, dwell: d.dwell ?? (d.urgent ? 6000 : 4200) },
            dl: { icon: "download", label: d.name ?? "", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.accent, w: 360, h: 56, bar: true },
            dnd: { icon: toggles.dnd ? "do_not_disturb_on" : "notifications", label: "Do not disturb " + (toggles.dnd ? "on" : "off"), sub: "", color: toggles.dnd ? Theme.warning : Theme.accent, w: 310, h: 46 },
            night: { icon: "nightlight", label: "Night light " + (toggles.night ? "on" : "off"), sub: NightLight.temperature + " K", color: Theme.warning, w: 310, h: 46 },
            qrres: { icon: "qr_code_scanner", label: d.label ?? "", sub: d.sub ?? "", color: Theme.success, w: 430, h: 56, dwell: 5200 },
            shelf: { icon: "inbox", label: d.label ?? "Added to shelf", sub: d.sub ?? "", color: Theme.success, w: 330, h: 48 },
            lsdone: { icon: d.bad ? "error" : "download_done", label: d.label ?? "Received", sub: d.sub ?? "", color: d.bad ? Theme.warning : Theme.success, w: 380, h: 48 }
        };
        const base = { icon: "info", label: "", sub: "", pct: 0, color: Theme.accent, w: 320, h: 48, bar: false, thumb: false, art: false, eq: false, save: false, right: "", persist: false, dwell: 2900 };
        return Object.assign({}, base, S[kind] ?? {});
    }
}
