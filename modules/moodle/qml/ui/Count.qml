import QtQuick
import "root:/singletons"
import "root:/store"

Rectangle {
    id: root

    property alias text: label.text
    property color tint: Theme.accent

    implicitWidth: Math.max(root.implicitHeight, label.implicitWidth + 9)
    implicitHeight: 17
    radius: Style.bare ? 0 : height / 2
    color: root.tint

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Style.family
        font.pixelSize: Style.tiny
        font.weight: Font.Medium
        color: Style.onAccent
    }
}
