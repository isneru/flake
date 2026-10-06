import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

Rectangle {
    id: root

    property var source: null
    property string icon: ""
    property string label: ""
    property string sub: ""
    property string glyph: "web_asset"
    signal chosen

    radius: Theme.rCard
    color: area.containsMouse ? Theme.s2 : Theme.s1
    border.width: 1
    border.color: area.containsMouse ? Theme.alpha(Theme.accent, 0.5) : "transparent"
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    Item {
        id: preview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: caption.top
        anchors.margins: 8
        anchors.bottomMargin: 4
        clip: true

        Icon {
            anchors.centerIn: parent
            visible: !view.hasContent
            size: 28
            text: root.glyph
            color: Theme.t4
        }

        ScreencopyView {
            id: view
            anchors.centerIn: parent
            captureSource: root.source
            live: false
            paintCursor: false
            visible: hasContent

            readonly property real ar: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
            width: Math.min(parent.width, parent.height * ar)
            height: ar > 0 ? width / ar : parent.height
        }
    }

    Item {
        id: caption
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 10
        height: 30

        Image {
            id: appIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            visible: root.icon !== "" && status === Image.Ready
            source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
            sourceSize.width: 36
            sourceSize.height: 36
        }

        Column {
            anchors.left: appIcon.visible ? appIcon.right : parent.left
            anchors.leftMargin: appIcon.visible ? 9 : 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.label
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.t1
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: root.sub !== "" && root.sub !== root.label
                text: root.sub
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t3
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }
}
