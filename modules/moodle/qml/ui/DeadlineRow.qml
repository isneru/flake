import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Rectangle {
    id: root

    property var event: null
    property bool showCourse: true

    readonly property real remaining: root.event ? root.event.when - Date.now() / 1000 : 0
    readonly property color urgency: root.remaining < 0 ? Theme.error : (root.remaining < 172800 ? Theme.warning : Style.muted)

    height: 52
    radius: Style.r(Theme.rRow)
    color: hover.hovered ? Style.surfaceHover : Style.surface

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
        onTapped: Moodle.browse(root.event ? root.event.url : "")
    }

    Hint {
        onActivated: Moodle.browse(root.event ? root.event.url : "")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 3
            Layout.preferredHeight: 26
            radius: Style.r(2)
            color: root.urgency
        }

        Icon {
            text: Moodle.modIcon(root.event ? root.event.modname : "")
            size: 17
            color: Style.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.event ? root.event.name : ""
                elide: Text.ElideRight
                font.family: Style.family
                font.pixelSize: Style.row
                font.weight: Font.Medium
                color: Style.text
            }

            Text {
                Layout.fillWidth: true
                visible: root.showCourse
                text: root.event ? root.event.course : ""
                elide: Text.ElideRight
                font.family: Style.family
                font.pixelSize: Style.small
                color: Style.faint
            }
        }

        ColumnLayout {
            spacing: 1

            Text {
                Layout.alignment: Qt.AlignRight
                text: root.event ? Moodle.due(root.event.when) : ""
                font.family: Style.family
                font.pixelSize: Style.body
                font.weight: Font.DemiBold
                color: root.urgency
            }

            Text {
                Layout.alignment: Qt.AlignRight
                text: root.event ? Moodle.stamp(root.event.when) : ""
                font.family: Style.family
                font.pixelSize: Style.tiny
                color: Style.faint
            }
        }
    }
}
