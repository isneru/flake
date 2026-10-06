import QtQuick
import "root:/singletons"

Item {
    id: root
    property int value: 50
    property color fill: Theme.accent
    property int trackWidth: 7
    signal moved(int v)

    implicitWidth: 22

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.trackWidth
        height: parent.height
        radius: width / 2
        color: Theme.track

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * Math.max(0, Math.min(100, root.value)) / 100
            radius: parent.radius
            color: root.fill
            Behavior on height { NumberAnimation { duration: 110 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function apply(my) {
            const v = Math.round(100 * Math.max(0, Math.min(1, 1 - my / root.height)));
            root.value = v;
            root.moved(v);
        }
        onPressed: e => apply(e.y)
        onPositionChanged: e => { if (pressed) apply(e.y); }
    }
}
