import QtQuick
import "root:/singletons"
import "root:/components"

Item {
    Column {
        anchors.centerIn: parent
        spacing: 10

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 30
            text: "construction"
            color: Theme.t4
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: NotchState.panel + " panel — not built yet"
            font.family: Theme.ui
            font.pixelSize: 13
            color: Theme.t3
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "spec: design_handoff_notch_shell/README.md"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.t4
        }
    }
}
