import QtQuick
import "root:/singletons"

Rectangle {
    id: root

    property alias text: label.text
    property color tint: Theme.accent
    property real size: 16

    implicitWidth: Math.max(size, label.implicitWidth + size * 0.55)
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: tint

    Text {
        id: label
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.ui
        font.pixelSize: Math.round(root.size * 0.62)
        font.weight: Font.Medium
        color: Theme.fgOnAccent
    }
}
