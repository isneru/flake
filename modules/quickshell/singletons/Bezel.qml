pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int rounding: 12
    property int gap: 8
    readonly property int radius: rounding + gap

    Process {
        running: true
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text).int;
                    if (Number.isInteger(v))
                        root.rounding = v;
                } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = parseInt(JSON.parse(text).css.trim().split(/\s+/)[0], 10);
                    if (!isNaN(v))
                        root.gap = v;
                } catch (e) {}
            }
        }
    }
}
