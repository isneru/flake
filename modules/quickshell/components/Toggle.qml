import QtQuick
import "root:/singletons"

Rectangle {
    id: root
    property bool checked: false
    property color activeColor: Theme.accent
    signal toggled

    implicitWidth: 36
    implicitHeight: 21
    radius: height / 2
    color: checked ? activeColor : Theme.alpha(Theme.t1, 0.14)
    Behavior on color { ColorAnimation { duration: 240 } }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: "#ffffff"
        y: 2.5
        x: root.checked ? root.width - width - 2.5 : 2.5
        Behavior on x {
            NumberAnimation {
                duration: 240
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.34, 1.4, 0.64, 1, 1, 1]
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
