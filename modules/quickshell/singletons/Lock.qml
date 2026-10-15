pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    property bool locked: false
    property double lockedAt: 0
    property string wallpaper: ""

    function lock() {
        if (locked)
            return;
        lockedAt = Date.now();
        locked = true;
        setHint(true);
    }

    readonly property string marker: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-unlocked`

    Timer {
        id: startupLock
        interval: 420
        onTriggered: root.lock()
    }

    FileView {
        id: session
        path: root.marker
        onLoadFailed: if (!root.locked) startupLock.start()
    }

    Process {
        running: true
        command: [
            "busctl",
            "get-property",
            "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session",
            "LockedHint"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().split(/\s+/).pop() === "true") {
                    startupLock.stop();
                    root.lock();
                }
            }
        }
    }

    function setHint(on) {
        Quickshell.execDetached([
            "busctl", "call", "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session", "SetLockedHint", "b", on ? "true" : "false"
        ]);
    }

    function unlock() {
        if (!locked)
            return;
        locked = false;
        setHint(false);
        session.setText("1\n");
    }

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/wallpaper`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallpaper = text().trim()
        onLoadFailed: root.wallpaper = ""
    }
}
