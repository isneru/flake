import QtQuick
import "root:/singletons"

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool on: false
    property color activeColor: Theme.accent
    property bool scrollable: false
    signal clicked
    signal scrolled(int steps)

    implicitHeight: 78
    radius: 15
    color: on ? activeColor : Theme.s2
    Behavior on color { ColorAnimation { duration: 240 } }

    readonly property color fg: on ? Theme.fgOnAccent : Qt.rgba(1, 1, 1, 0.92)
    readonly property color sub2: on ? Qt.rgba(0, 0, 0, 0.5) : Theme.t3

    Icon {
        x: 12
        y: 11
        size: 20
        filled: true
        text: root.icon
        color: root.fg
    }

    Column {
        x: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 11
        width: parent.width - 24
        spacing: 0

        Text {
            text: root.label
            font.family: Theme.ui
            font.pixelSize: 12
            font.weight: Font.Medium
            color: root.fg
        }
        Text {
            text: root.sub
            font.family: Theme.ui
            font.pixelSize: 11
            color: root.sub2
            width: parent.width
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
        onEntered: root.scale = 1.01
        onExited: root.scale = 1
        onWheel: wheel => {
            if (!root.scrollable) {
                wheel.accepted = false;
                return;
            }
            if (wheel.angleDelta.y !== 0)
                root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1);
        }
    }
    Behavior on scale { NumberAnimation { duration: 180 } }
}
