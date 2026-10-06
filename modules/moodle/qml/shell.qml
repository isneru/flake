//@ pragma AppId moodle
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"
import "root:/store"
import "root:/ui"

ShellRoot {
    FloatingWindow {
        title: "Moodle"
        implicitWidth: 1280
        implicitHeight: 840
        minimumSize: Qt.size(940, 620)
        color: Theme.bg

        App {
            anchors.fill: parent
            focus: true
        }
    }

    Connections {
        target: Quickshell
        function onLastWindowClosed(): void {
            Qt.quit();
        }
    }

    IpcHandler {
        target: "moodle"
        function sync(): void {
            Moodle.sync();
        }
        function status(): string {
            return Moodle.ready ? `${Moodle.shown.length} courses, synced ${Moodle.stamp(Moodle.updated)}` : "not synced";
        }
    }
}
