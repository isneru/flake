import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Rectangle {
    id: root

    property var file: null

    height: 34
    radius: Style.r(9)
    color: hover.hovered ? Style.surfaceHover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: Moodle.open(root.file ? root.file.path : "")
    }

    Hint {
        onActivated: Moodle.open(root.file ? root.file.path : "")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 8

        Icon {
            text: root.file ? Moodle.fileIcon(root.file.mime, root.file.name) : "draft"
            size: 16
            color: Style.muted
        }

        Text {
            Layout.fillWidth: true
            text: root.file ? root.file.name : ""
            elide: Text.ElideMiddle
            font.family: Style.family
            font.pixelSize: Style.body
            color: Style.dim
        }

        Text {
            text: root.file ? Moodle.size(root.file.size) : ""
            font.family: Style.monoFamily
            font.pixelSize: Style.tiny
            color: Style.faint
        }

        IconButton {
            glyph: "folder_open"
            tint: Style.faint
            onActivated: Moodle.reveal(root.file ? root.file.path : "")
        }
    }
}
