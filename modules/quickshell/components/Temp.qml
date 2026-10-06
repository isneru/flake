import QtQuick
import "root:/singletons"

Item {
    id: root

    property string value: ""
    property real size: 14
    property int weight: Font.Medium
    property color tint: Theme.t1

    implicitWidth: num.implicitWidth
    implicitHeight: num.implicitHeight

    Text {
        id: num
        anchors.centerIn: parent
        text: root.value
        font.family: Theme.mono
        font.pixelSize: root.size
        font.weight: root.weight
        color: root.tint
    }

    Text {
        anchors.left: num.right
        anchors.top: num.top
        text: "°"
        font.family: Theme.mono
        font.pixelSize: root.size
        font.weight: root.weight
        color: root.tint
    }
}
