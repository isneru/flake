pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property int barFont: Theme.themeSizeSmall
    readonly property int barHeight: barFont + 12
    readonly property int barIcon: Math.round(barFont * 0.8)

    property bool soft: false
    readonly property int radius: 0

    function alpha(c, a) {
        return Theme.alpha(c, soft ? 1 : a);
    }

    signal popRequested(string kind)

    property bool cheatsheet: false
    property bool overview: false

    function current() {
        return soft ? "soft" : "flat";
    }

    function set(v) {
        if (v === soft)
            return;
        soft = v;
        applier.running = false;
        applier.command = ["bare-look", current()];
        applier.running = true;
    }

    function toggle() {
        set(!soft);
    }

    Process { id: applier }

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/look`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.soft = text().trim() === "soft"
    }
}
