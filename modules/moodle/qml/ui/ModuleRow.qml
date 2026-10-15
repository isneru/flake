import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Rectangle {
    id: root

    property var module: null
    property bool expanded: false

    readonly property var files: root.module && root.module.files ? root.module.files : []
    readonly property var links: root.module && root.module.links ? root.module.links : []
    readonly property string body: root.module && root.module.html ? root.module.html : ""
    readonly property bool label: root.module && root.module.modname === "label"
    readonly property bool openable: root.body !== "" || root.files.length > 0 || root.links.length > 0
    readonly property bool jumpsToLink: root.module && root.module.modname === "url" && root.links.length > 0
    readonly property bool opensOneFile: root.files.length === 1 && root.body === ""
    readonly property bool expandable: root.openable && !root.jumpsToLink && !root.opensOneFile

    implicitHeight: column.implicitHeight + 16
    radius: Style.r(Theme.rRow)
    color: root.label ? "transparent" : (hover.hovered || root.expanded ? Style.surfaceHover : Style.surface)

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    function primary(): void {
        if (!root.module)
            return;
        if (root.expandable)
            root.expanded = !root.expanded;
        else if (root.jumpsToLink)
            Moodle.browse(root.links[0].url);
        else if (root.opensOneFile)
            Moodle.open(root.files[0].path);
        else
            Moodle.browse(root.module.url);
    }

    HoverHandler {
        id: hover
        enabled: !root.label
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: !root.label
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.primary()
    }

    Hint {
        enabled: !root.label
        onActivated: root.primary()
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        anchors.topMargin: 8
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            visible: !root.label
            spacing: 9

            Icon {
                text: Moodle.modIcon(root.module ? root.module.modname : "")
                size: 17
                color: root.expanded ? Theme.accent : Style.muted
            }

            Text {
                Layout.fillWidth: true
                text: root.module ? root.module.name : ""
                elide: Text.ElideRight
                font.family: Style.family
                font.pixelSize: Style.row
                font.weight: Font.Medium
                color: root.module && root.module.visible ? Style.text : Style.faint
            }

            Chip {
                visible: root.files.length > 1
                text: root.files.length + " files"
            }

            Icon {
                visible: root.expandable
                text: "expand_more"
                size: 16
                color: Style.faint
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }

            IconButton {
                glyph: "open_in_new"
                tint: Style.faint
                onActivated: Moodle.browse(root.module ? root.module.url : "")
            }
        }

        Rich {
            Layout.fillWidth: true
            Layout.leftMargin: root.label ? 0 : 26
            visible: root.body !== "" && (root.expanded || root.label)
            text: root.body
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            visible: root.expanded
            spacing: 2

            Repeater {
                model: root.expanded ? root.files : []

                delegate: FileRow {
                    required property var modelData
                    Layout.fillWidth: true
                    file: modelData
                }
            }

            Repeater {
                model: root.expanded ? root.links : []

                delegate: Rectangle {
                    id: link

                    required property var modelData

                    Layout.fillWidth: true
                    height: 32
                    radius: Style.r(9)
                    color: linkHover.hovered ? Style.surfaceHover : "transparent"

                    HoverHandler {
                        id: linkHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Moodle.browse(link.modelData.url)
                    }

                    Hint {
                        onActivated: Moodle.browse(link.modelData.url)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Icon {
                            text: "link"
                            size: 15
                            color: Style.muted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: link.modelData.url
                            elide: Text.ElideRight
                            font.family: Style.family
                            font.pixelSize: Style.body
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }
}
