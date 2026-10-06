import QtQuick
import Quickshell.Hyprland
import "root:/singletons"

Item {
    id: root

    readonly property int notifCount: Notifs.count
    readonly property var spaces: Hyprland.workspaces.values.filter(w => w.id > 0)

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Repeater {
            model: root.spaces
            delegate: Rectangle {
                required property var modelData
                readonly property bool active: Hyprland.focusedWorkspace?.id === modelData.id
                anchors.verticalCenter: parent.verticalCenter
                width: active ? 16 : 6
                height: 6
                radius: 3
                color: active ? Theme.accent : Qt.rgba(1, 1, 1, 0.28)
                Behavior on width { NumberAnimation { duration: 300 } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.mono
            font.pixelSize: 15
            font.weight: Font.Medium
            font.letterSpacing: 0.75
            color: Theme.t1
        }
        Text {
            visible: root.notifCount > 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.notifCount + (root.notifCount === 1 ? " notification" : " notifications")
            font.family: Theme.ui
            font.pixelSize: 10
            color: Theme.alpha(Theme.t1, 0.45)
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Rectangle {
            visible: Audio.muted
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Theme.warning
        }
        Rectangle {
            visible: NotchState.toggles.dnd
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Theme.error
        }
        Rectangle {
            visible: NightLight.enabled
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Theme.info
        }
        Rectangle {
            visible: NotchState.micInUse
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Theme.success
        }
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: date = new Date()
    }

    opacity: 0
    scale: 0.96
    Component.onCompleted: { opacity = 1; scale = 1; }
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.2, 1, 1, 1] } }
    Behavior on scale { NumberAnimation { duration: 300 } }
}
