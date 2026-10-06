pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property bool bare: Persist.bare

    readonly property int barFont: Theme.themeSizeSmall
    readonly property int barHeight: barFont + 12
    readonly property int barIcon: Math.round(barFont * 0.8)

    readonly property var routes: ({
        launcher: "run",
        clip: "clip",
        power: "power",
        wall: "wall",
        theme: "theme",
        wifi: "wifi",
        media: "media",
        tray: "tray",
        spaces: "windows",
        send: "send",
        calc: "calc",
        timer: "timer",
        shelf: "shelf",
        home: "home",
        record: "record",
        control: "control",
        bt: "bt",
        audio: "audio",
        notif: "notifs",
        cal: "calendar",
        net: "net",
        repos: "repos"
    })

    readonly property var pops: ({
        weather: "weather",
        monitor: "monitor",
        display: "displays",
        netstats: "net",
        wifiqr: "qr"
    })

    signal popRequested(string kind)

    property bool cheatsheet: false
    onBareChanged: cheatsheet = false

    function route(panel) {
        if (!bare)
            return false;
        if (panel === "keys") {
            cheatsheet = !cheatsheet;
            return true;
        }
        if (pops[panel]) {
            popRequested(pops[panel]);
            return true;
        }
        const src = routes[panel];
        if (src)
            Quickshell.execDetached(["notch-pick", src]);
        return true;
    }

    function current() {
        return bare ? "bare" : "notch";
    }

    function toggle() {
        return set(!Persist.bare);
    }

    function set(v) {
        if (NotchState.modal || v === Persist.bare)
            return false;
        NotchState.close();
        Persist.setBare(v);
        apply();
        return true;
    }

    Process { id: applier }

    function apply() {
        applier.running = false;
        applier.command = ["notch-mode", current()];
        applier.running = true;
    }
}
