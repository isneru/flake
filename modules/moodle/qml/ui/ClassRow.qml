import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Rectangle {
    id: root

    property var lecture: null
    property bool showCourse: true

    readonly property bool live: root.lecture ? root.lecture.start <= Moodle.now : false
    readonly property var course: root.lecture ? Moodle.courses.find(c => c.id === root.lecture.courseId) ?? null : null
    readonly property bool linked: root.showCourse && root.course !== null

    height: 52
    radius: Style.r(Theme.rRow)
    color: hover.hovered && root.linked ? Style.surfaceHover : Style.surface

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    HoverHandler {
        id: hover
        cursorShape: root.linked ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.linked
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: Moodle.select(root.lecture.courseId)
    }

    Hint {
        enabled: root.linked
        onActivated: Moodle.select(root.lecture.courseId)
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
            color: root.live ? Theme.success : Theme.accent
        }

        Icon {
            text: "school"
            size: 17
            color: Style.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.showCourse ? (root.course ? root.course.fullname : (root.lecture ? root.lecture.code : "")) : (root.lecture ? Qt.formatDateTime(new Date(root.lecture.start), "dddd d MMMM") : "")
                elide: Text.ElideRight
                font.family: Style.family
                font.pixelSize: Style.row
                font.weight: Font.Medium
                color: Style.text
            }

            Text {
                Layout.fillWidth: true
                text: root.lecture ? [root.showCourse ? root.lecture.code : "", root.lecture.kind, root.lecture.room, root.lecture.teacher].filter(s => s).join("  ·  ") : ""
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
                text: root.lecture ? Moodle.until(root.lecture) : ""
                font.family: Style.family
                font.pixelSize: Style.body
                font.weight: Font.DemiBold
                color: root.live ? Theme.success : Style.dim
            }

            Text {
                Layout.alignment: Qt.AlignRight
                text: root.lecture ? Moodle.span(root.lecture) : ""
                font.family: Style.family
                font.pixelSize: Style.tiny
                color: Style.faint
            }
        }
    }
}
