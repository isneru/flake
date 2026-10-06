import QtQuick
import "root:/singletons"
import "root:/components"

Item {
    id: root
    readonly property var act: Activities.active

    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.family: Theme.mono
        font.pixelSize: 15
        font.weight: Font.Medium
        font.letterSpacing: 0.9
        color: Qt.rgba(1, 1, 1, 0.94)
    }

    Row {
        id: chip
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        visible: root.act !== null
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.act !== null && root.act.icon === ""
            width: 6
            height: 6
            radius: 3
            color: root.act?.color ?? Theme.accent
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.act !== null && root.act.icon !== ""
            size: 15
            filled: true
            text: root.act?.icon ?? ""
            color: root.act?.color ?? Theme.accent
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.act?.label ?? ""
            font.family: Theme.mono
            font.pixelSize: 13
            font.weight: Font.Medium
            color: root.act?.color ?? Theme.accent
        }

        SequentialAnimation on opacity {
            running: root.act?.blink ?? false
            loops: Animation.Infinite
            onRunningChanged: if (!running) chip.opacity = 1
            NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
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
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: 260 } }
}
