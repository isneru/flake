import QtQuick
import "root:/singletons"
import "root:/store"
import "root:/components"

Rectangle {
    id: root

    property string glyph: ""
    property bool active: false
    property bool spinning: false
    property color tint: Style.dim
    signal activated

    implicitWidth: 28
    implicitHeight: 28
    radius: Style.r(9)
    color: root.active ? Style.surfaceActive : (hover.hovered ? Style.surfaceHover : "transparent")

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
        onTapped: root.activated()
    }

    Hint {
        onActivated: root.activated()
    }

    Icon {
        id: mark
        anchors.centerIn: parent
        text: root.glyph
        size: 16
        color: root.active ? Theme.accent : (hover.hovered ? Style.text : root.tint)

        RotationAnimation on rotation {
            running: root.spinning
            from: 0
            to: 360
            duration: 1100
            loops: Animation.Infinite
            onRunningChanged: if (!running)
                mark.rotation = 0
        }
    }
}
