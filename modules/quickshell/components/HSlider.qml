import QtQuick
import "root:/singletons"

Item {
    id: root
    property int value: 50
    property color fill: Theme.accent
    property int trackHeight: 7
    signal moved(int v)

    implicitHeight: 22

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: Theme.track

        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
            height: parent.height
            radius: parent.radius
            color: root.fill
            Behavior on width { NumberAnimation { duration: 110 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function apply(mx) {
            const v = Math.round(100 * Math.max(0, Math.min(1, mx / root.width)));
            root.value = v;
            root.moved(v);
        }
        onPressed: e => apply(e.x)
        onPositionChanged: e => { if (pressed) apply(e.x); }
    }
}
