pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var macRe: /^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i

    readonly property var kinds: ({
            "audio-card": "Speaker",
            "audio-headphones": "Headphones",
            "audio-headset": "Headset",
            "audio-speakers": "Speaker",
            "camera-photo": "Camera",
            "camera-video": "Camera",
            "computer": "Computer",
            "input-gaming": "Controller",
            "input-keyboard": "Keyboard",
            "input-mouse": "Mouse",
            "input-tablet": "Tablet",
            "modem": "Modem",
            "multimedia-player": "Media player",
            "network-wireless": "Network device",
            "phone": "Phone",
            "printer": "Printer",
            "scanner": "Scanner"
        })

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property int discoverWindow: 180
    property real discoverUntil: 0
    property int discoverLeft: 0

    function named(d) {
        const n = d?.name || d?.deviceName || "";
        return n && !root.macRe.test(n) ? n : "";
    }

    function display(d) {
        return root.named(d) || root.kinds[d?.icon ?? ""] || "Unknown device";
    }

    function tail(d) {
        if (root.named(d))
            return "";
        const a = d?.address ?? "";
        return a.length >= 5 ? a.slice(-5) : a;
    }

    function clock(s) {
        const t = Math.max(0, Math.round(s));
        return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2);
    }

    function setDiscoverable(on) {
        const a = root.adapter;
        if (!a)
            return;
        if (!on) {
            a.discoverable = false;
            a.pairable = false;
            return;
        }
        root.discoverUntil = Date.now() + root.discoverWindow * 1000;
        a.discoverableTimeout = root.discoverWindow;
        a.pairableTimeout = root.discoverWindow;
        a.pairable = true;
        a.discoverable = true;
        root.tick();
    }

    function tick() {
        root.discoverLeft = root.discoverUntil > Date.now()
            ? Math.round((root.discoverUntil - Date.now()) / 1000)
            : 0;
    }

    function retime() {
        const a = root.adapter;
        if (!(a?.discoverable ?? false)) {
            root.discoverUntil = 0;
            root.discoverLeft = 0;
            return;
        }
        if (root.discoverUntil <= Date.now())
            root.discoverUntil = Date.now() + (a.discoverableTimeout ?? 0) * 1000;
        root.tick();
    }

    Component.onCompleted: root.retime()

    Connections {
        target: root.adapter
        function onDiscoverableChanged() {
            root.retime();
        }
    }

    Timer {
        running: root.adapter?.discoverable ?? false
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: root.tick()
    }
}
