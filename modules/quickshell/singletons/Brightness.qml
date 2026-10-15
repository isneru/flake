pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int max: 0
    property int raw: 0
    readonly property int percent: max > 0 ? Math.round(100 * raw / max) : 0
    property string device: ""

    Process {
        id: probe
        running: true
        command: ["brightnessctl", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length < 5)
                    return;
                root.device = f[0];
                root.raw = parseInt(f[2]) || 0;
                root.max = parseInt(f[4]) || 0;
            }
        }
    }

    Process { id: setter }

    function set(pct) {
        const p = Math.max(1, Math.min(100, Math.round(pct)));
        raw = Math.round(max * p / 100);
        setter.running = false;
        setter.command = ["brightnessctl", "-n", "set", p + "%"];
        setter.running = true;
    }

    function step(delta) {
        set(percent + delta);
    }

    FileView {
        id: level
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: root.raw = parseInt(text()) || root.raw
    }

    Timer {
        interval: 3000
        running: root.device !== ""
        repeat: true
        onTriggered: level.reload()
    }
}
