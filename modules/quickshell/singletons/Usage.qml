pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var counts: ({})
    property bool loaded: false

    function count(id) {
        return id ? (counts[id] ?? 0) : 0;
    }

    function bump(id) {
        if (!id)
            return;
        const next = Object.assign({}, counts);
        next[id] = count(id) + 1;
        counts = next;
        save();
    }

    function clear() {
        counts = ({});
        save();
    }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/usage.json`
        onLoaded: {
            try {
                root.counts = JSON.parse(text()) || ({});
            } catch (e) {
                root.counts = ({});
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    function save() {
        if (!loaded)
            return;
        file.setText(JSON.stringify(counts, null, 2));
    }
}
