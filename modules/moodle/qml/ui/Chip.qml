import QtQuick
import "root:/singletons"
import "root:/store"

Rectangle {
    id: root

    property alias text: label.text
    property color tint: Style.muted

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 20
    radius: Style.r(6)
    color: Theme.alpha(root.tint, 0.14)

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Style.family
        font.pixelSize: Style.small
        font.weight: Font.Medium
        color: root.tint
    }
}
