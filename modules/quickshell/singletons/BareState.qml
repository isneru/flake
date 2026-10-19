pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "root:/singletons"

Singleton {
    id: root

    property string osdKind: ""
    readonly property bool isOsd: osdKind !== ""
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
    property bool recording: false
    property int recElapsed: 0

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

    readonly property string batterySysfs: battery?.nativePath ? "/sys/class/power_supply/" + battery.nativePath : ""
    FileView { id: batFull; blockLoading: true; path: root.batterySysfs ? root.batterySysfs + "/energy_full" : "" }
    FileView { id: batDesign; blockLoading: true; path: root.batterySysfs ? root.batterySysfs + "/energy_full_design" : "" }
    FileView { id: batCycles; blockLoading: true; path: root.batterySysfs ? root.batterySysfs + "/cycle_count" : "" }

    function batteryHealth() {
        const bits = [];
        const c = parseInt(batCycles.text());
        const f = parseInt(batFull.text());
        const d = parseInt(batDesign.text());
        if (c > 0)
            bits.push("cycles " + c);
        if (f > 0 && d > 0)
            bits.push("health " + Math.round(100 * f / d) + "%");
        return bits.join(", ");
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

    property string layoutName: ""
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const parts = event.data.split(",");
            const seen = root.layoutName;
            root.layoutName = parts[1] ?? "";
            if (!root.osdReady || seen === "" || seen === root.layoutName)
                return;
            root.showOsd("caps", { label: "Keyboard layout", sub: parts[0] ?? "", right: parts[1] ?? "" });
        }
    }

    property var inputEvent: ({})
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=input", "--property"]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("UDEV"))
                    root.inputEvent = {};
                else if (line.startsWith("ACTION="))
                    root.inputEvent.action = line.slice(7);
                else if (line.startsWith("NAME="))
                    root.inputEvent.name = line.slice(5).replace(/^"|"$/g, "");
                else if (line === "ID_INPUT_MOUSE=1" && root.osdReady && root.inputEvent.action === "add" && root.inputEvent.name)
                    root.showOsd("msg", { label: root.inputEvent.name, sub: "connected", color: Theme.accent });
            }
        }
    }

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
                root.showOsd("msg", say);
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

    function close() {
        osdKind = "";
    }
    function showOsd(kind, data) {
        osdData = data ?? ({});
        osdKind = kind;
        osdTimer.restart();
        if (osd.persist)
            osdTimer.stop();
    }

    Timer {
        id: osdTimer
        interval: root.osd.dwell
        onTriggered: root.close()
    }

    property bool osdHovered: false
    onOsdHoveredChanged: {
        if (!isOsd || osd.persist)
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
            vol: { label: "Volume", sub: d.sink ?? Audio.sinkName, pct: volume, color: Theme.accent, bar: true },
            bri: { label: "Brightness", sub: d.output ?? Brightness.device, pct: brightness, color: Theme.fg, bar: true },
            charge: { label: "Charging", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.success, bar: true },
            unplug: { label: "On battery", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.accent, bar: true },
            low: { label: "Battery low", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.warning, bar: true },
            bt: { label: d.name ?? "Device", sub: d.sub ?? "connected", color: Theme.accent },
            mic: { label: Audio.micMuted ? "Microphone muted" : "Microphone on", sub: Audio.sourceName, color: Audio.micMuted ? Theme.error : Theme.success },
            msg: { label: d.label ?? "", sub: d.sub ?? "", color: d.color ?? Theme.accent },
            shot: { label: d.saved ? "Saved to ~/pictures/screenshots" : "Copied to clipboard", sub: "", color: Theme.accent, save: !d.saved, dwell: 3600 },
            rec: { label: "Recording", sub: d.sub ?? "", color: Theme.error },
            caps: { label: d.label ?? "Caps Lock", sub: d.sub ?? "", color: Theme.accent },
            track: { label: d.title ?? "", sub: d.artist ?? "", color: Theme.accent },

            notif: { color: d.urgent ? Theme.error : Theme.accent, dwell: d.dwell ?? (d.urgent ? 6000 : 4200) },
            dl: { label: d.name ?? "", sub: d.sub ?? "", pct: d.pct ?? 0, color: Theme.accent, bar: true },
            dnd: { label: "Do not disturb " + (toggles.dnd ? "on" : "off"), sub: "", color: toggles.dnd ? Theme.warning : Theme.accent },
            night: { label: "Night light " + (toggles.night ? "on" : "off"), sub: NightLight.temperature + " K", color: Theme.warning },
            qrres: { label: d.label ?? "", sub: d.sub ?? "", color: Theme.success, dwell: 5200 },
            shelf: { label: d.label ?? "Added to shelf", sub: d.sub ?? "", color: Theme.success },
            lsdone: { label: d.label ?? "Received", sub: d.sub ?? "", color: d.bad ? Theme.warning : Theme.success }
        };
        const base = { label: "", sub: "", pct: 0, color: Theme.accent, bar: false, save: false, persist: false, dwell: 2900 };
        return Object.assign({}, base, S[kind] ?? {});
    }
}
