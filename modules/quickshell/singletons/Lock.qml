pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    property string phase: "idle"
    property real wp: 0
    property real hp: 0

    property bool locked: false
    property bool closing: false
    property double lockedAt: 0
    property string wallpaper: ""

    readonly property bool active: phase !== "idle"
    readonly property bool covering: phase === "covering"
    readonly property bool uncovering: phase === "uncovering"

    readonly property var liquid: [0.65, 0, 0.25, 1, 1, 1]

    readonly property int widthDur: 340
    readonly property int heightDur: 300
    readonly property int overlap: 240

    ParallelAnimation {
        id: openAnim
        onFinished: root.engage()

        NumberAnimation {
            target: root
            property: "wp"
            to: 1
            duration: root.widthDur
            easing.type: Easing.Bezier
            easing.bezierCurve: root.liquid
        }
        SequentialAnimation {
            PauseAnimation { duration: root.overlap }
            NumberAnimation {
                target: root
                property: "hp"
                to: 1
                duration: root.heightDur
                easing.type: Easing.InQuart
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        onFinished: root.done()

        NumberAnimation {
            target: root
            property: "hp"
            to: 0
            duration: Math.round(root.heightDur * 0.85)
            easing.type: Easing.OutQuart
        }
        SequentialAnimation {
            PauseAnimation { duration: Math.round(root.overlap * 0.75) }
            NumberAnimation {
                target: root
                property: "wp"
                to: 0
                duration: Math.round(root.widthDur * 0.85)
                easing.type: Easing.Bezier
                easing.bezierCurve: root.liquid
            }
        }
    }

    function lock() {
        if (active)
            return;
        lockedAt = Date.now();
        closing = false;
        NotchState.close();
        wp = Mode.bare ? 1 : 0;
        hp = Mode.bare ? 1 : 0;
        phase = "covering";
        if (Mode.bare)
            engage();
        else
            openAnim.start();
    }

    readonly property string marker: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-unlocked`

    Timer {
        id: startupMorph
        interval: 420
        onTriggered: root.lock()
    }

    FileView {
        id: session
        path: root.marker
        onLoadFailed: if (!root.active) startupMorph.start()
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
                    startupMorph.stop();
                    root.engageAtStartup();
                }
            }
        }
    }

    function engageAtStartup() {
        if (active)
            return;
        lockedAt = Date.now();
        closing = false;
        wp = 1;
        hp = 1;
        phase = "locked";
        locked = true;
        setHint(true);
    }

    function engage() {
        if (phase !== "covering")
            return;
        phase = "locked";
        locked = true;
        setHint(true);
    }

    function setHint(on) {
        Quickshell.execDetached([
            "busctl", "call", "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session", "SetLockedHint", "b", on ? "true" : "false"
        ]);
    }

    function beginUnlock() {
        if (phase !== "locked" || closing)
            return;
        closing = true;
    }

    function release() {
        if (phase !== "locked")
            return;
        locked = false;
        closing = false;
        setHint(false);
        phase = "uncovering";
        if (Mode.bare)
            done();
        else
            closeAnim.start();
    }

    function done() {
        if (phase !== "uncovering")
            return;
        phase = "idle";
        wp = 0;
        hp = 0;
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
