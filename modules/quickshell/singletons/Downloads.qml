pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var items: []

    readonly property int count: items.length
    readonly property var active: items.length ? items[0] : null

    readonly property int percent: {
        let done = 0;
        let total = 0;
        for (const it of items) {
            if (it.total > 0) {
                done += it.done;
                total += it.total;
            }
        }
        return total > 0 ? Math.floor(100 * done / total) : -1;
    }

    readonly property string label: {
        if (!count)
            return "";
        if (percent >= 0)
            return percent + "%";
        return fmtBytes(items.reduce((n, it) => n + (it.done ?? 0), 0));
    }

    function fmtBytes(n) {
        if (n < 1024)
            return n + " B";
        if (n < 1024 * 1024)
            return Math.round(n / 1024) + " KB";
        if (n < 1024 * 1024 * 1024)
            return (n / (1024 * 1024)).toFixed(1) + " MB";
        return (n / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/downloads.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: root.items = []
    }

    function apply(txt) {
        try {
            const j = JSON.parse(txt);
            items = Array.isArray(j.active) ? j.active : [];
        } catch (e) {
            items = [];
        }
    }
}
