import QtQuick
import "root:/singletons"
import "root:/components"

Rectangle {
    id: root
    property string icon: ""
    signal tapped

    width: 30
    height: 30
    radius: 15
    color: hover.hovered ? Theme.s4 : Theme.s2
    Behavior on color { ColorAnimation { duration: 160 } }

    Icon {
        anchors.centerIn: parent
        size: 17
        text: root.icon
        color: Qt.rgba(1, 1, 1, 0.8)
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: root.tapped() }
}
