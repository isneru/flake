pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var tops: Hyprland.toplevels.values
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
    property var ppids: ({})

    readonly property var pids: {
        const seen = [];
        for (const n of root.streams) {
            const pid = root.pidOf(n);
            if (pid && !seen.includes(pid))
                seen.push(pid);
        }
        return seen;
    }

    Instantiator {
        model: root.pids
        delegate: FileView {
            required property int modelData
            path: "/proc/" + modelData + "/status"
            onLoaded: {
                const next = Object.assign({}, root.ppids);
                next[modelData] = parseInt(text().match(/^PPid:\s*(\d+)/m)?.[1] ?? "0");
                root.ppids = next;
            }
        }
    }

    function pidOf(n) {
        return parseInt(n?.properties?.["application.process.id"] ?? "0") || 0;
    }

    function classFor(pid) {
        if (!pid)
            return "";
        for (const t of root.tops)
            if (t.lastIpcObject?.pid === pid)
                return t.lastIpcObject?.class ?? "";
        return "";
    }

    function nameFor(n) {
        if (!n)
            return "";
        const pid = root.pidOf(n);
        return root.classFor(pid) || root.classFor(root.ppids[pid] ?? 0)
            || (n.properties?.["application.name"] ?? n.description ?? n.name ?? "").replace(/ input$/, "");
    }
}
