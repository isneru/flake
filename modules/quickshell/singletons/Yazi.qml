pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property var appIds: ["yazi", "filepicker"]
    readonly property var focused: Hyprland.activeToplevel
    readonly property bool watching: Mode.bare && root.appIds.includes(root.focused?.wayland?.appId ?? "")
    readonly property int pid: root.watching ? (root.focused?.lastIpcObject?.pid ?? 0) : 0

    property var state: ({})
    property int retries: 0

    readonly property bool running: root.pid > 0 && root.state.id !== undefined
    readonly property string mode: state.mode ?? "normal"
    readonly property int cursor: state.cursor ?? 0
    readonly property int files: state.files ?? 0
    readonly property int tasks: state.tasks ?? 0

    readonly property string percentLabel: {
        if (root.files === 0 || root.cursor === 0)
            return "[top]";
        const p = Math.floor((root.cursor + 1) * 100 / root.files);
        return p >= 100 ? "[bot]" : `[${String(p).padStart(2, "0")}%]`;
    }

    readonly property string permRich: {
        const perm = state.perm ?? "";
        let out = "";
        for (let i = 0; i < perm.length; i++) {
            const c = perm[i];
            let color = Theme.ansiGreen;
            if (c === "-" || c === "?")
                color = Theme.fgMuted;
            else if (c === "r")
                color = Theme.ansiYellow;
            else if (c === "w")
                color = Theme.ansiRed;
            else if ("xsStT".includes(c))
                color = Theme.ansiCyan;
            else if (i > 0)
                color = Theme.fg;
            out += `<font color="${color}">${c}</font>`;
        }
        return out;
    }

    onFocusedChanged: {
        if (root.watching)
            Hyprland.refreshToplevels();
    }
    onWatchingChanged: {
        if (root.watching)
            Hyprland.refreshToplevels();
    }
    onPidChanged: {
        root.state = {};
        root.retries = 0;
    }

    function send(...args) {
        if (!root.running)
            return;
        Quickshell.execDetached(["ya", "emit-to", String(root.state.id)].concat(args));
    }

    LazyLoader {
        id: loader
        active: root.pid > 0
        component: FileView {
            path: root.pid > 0 ? `${Quickshell.env("XDG_RUNTIME_DIR")}/yazi-bar-${root.pid}.json` : ""
            watchChanges: true
            onFileChanged: reload()
            onLoaded: root.apply(text())
            onLoadFailed: root.state = {}
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.pid > 0 && !root.running && root.retries < 8
        onTriggered: {
            root.retries++;
            loader.active = false;
            loader.active = Qt.binding(() => root.pid > 0);
        }
    }

    function apply(txt) {
        try {
            root.state = JSON.parse(txt);
        } catch (e) {}
    }
}
