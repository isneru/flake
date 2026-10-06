import QtQuick
import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    visible: NotchState.isExpanded || fadeOut.running
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notch-scrim"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: NotchState.isExpanded ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fadeOut; duration: 420 } }
        MouseArea {
            anchors.fill: parent
            onClicked: NotchState.close()
        }
    }
}
