import QtQuick
import "root:/singletons"
import "root:/components"

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: Theme.rPeek
        color: Theme.alpha(Theme.success, 0.08)
        border.width: 1
        border.color: Theme.alpha(Theme.success, 0.45)

        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 11

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            size: 24
            filled: true
            text: "inbox"
            color: Theme.success
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: "Drop to shelf"
                font.family: Theme.ui
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Theme.t1
            }
            Text {
                text: Shelf.count > 0 ? Shelf.count + " already held" : "files are held by path"
                font.family: Theme.ui
                font.pixelSize: 11
                color: Theme.t3
            }
        }
    }

    opacity: 0
    scale: 0.96
    Component.onCompleted: { opacity = 1; scale = 1; }
    Behavior on opacity { NumberAnimation { duration: 200 } }
    Behavior on scale { NumberAnimation { duration: 200 } }
}
