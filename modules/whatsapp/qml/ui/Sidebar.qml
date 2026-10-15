import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/singletons"
import "root:/components"
import "root:/store"

Rectangle {
    id: root

    property alias list: chats

    color: Style.sidebar

    signal done
    signal picked

    function focusSearch(): void {
        field.forceActiveFocus();
    }

    function pickFirst(): void {
        if (Chats.shown.length)
            Chats.select(Chats.shown[0].jid);
        Chats.query = "";
        root.picked();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                text: "forum"
                size: 20
                color: Theme.accent
            }

            Column {
                Layout.fillWidth: true

                Text {
                    width: parent.width
                    text: Chats.me || "WhatsApp"
                    elide: Text.ElideRight
                    font.family: Style.family
                    font.pixelSize: Style.row
                    font.weight: Font.DemiBold
                    color: Style.text
                }

                Text {
                    visible: Chats.state !== "connected"
                    text: Chats.state === "connecting" ? "connecting…" : Chats.state === "outdated" ? "client outdated" : Chats.state === "replaced" ? "replaced by another session" : Chats.state === "logged-out" ? "not linked" : "daemon not running"
                    font.family: Style.family
                    font.pixelSize: Style.small
                    color: Chats.state === "connecting" ? Style.muted : Theme.warning
                }
            }

            IconButton {
                glyph: "archive"
                active: Chats.archived
                onActivated: Chats.archived = !Chats.archived

                Rectangle {
                    visible: Chats.archivedUnread > 0 && !Chats.archived
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 4
                    width: 6
                    height: 6
                    color: Theme.accent
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: Style.r(10)
            color: field.activeFocus ? Style.surfaceActive : Style.surface

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 6

                Icon {
                    text: "search"
                    size: 15
                    color: Style.muted
                }

                TextInput {
                    id: field
                    Layout.fillWidth: true
                    text: Chats.query
                    onTextChanged: Chats.query = text
                    font.family: Style.family
                    font.pixelSize: Style.body
                    color: Style.text
                    selectionColor: Theme.accent
                    selectedTextColor: Style.onAccent
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    Keys.onEscapePressed: {
                        Chats.query = "";
                        root.done();
                    }
                    Keys.onReturnPressed: root.pickFirst()
                    Keys.onEnterPressed: root.pickFirst()

                    Text {
                        anchors.fill: parent
                        visible: !field.text
                        text: Chats.archived ? "Search archived" : "Search chats"
                        font: field.font
                        color: Style.faint
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Text {
            visible: Chats.archived && !Chats.query
            text: "ARCHIVED"
            font.family: Style.family
            font.pixelSize: Style.tiny
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            color: Style.muted
        }

        ListView {
            id: chats

            signal tapped

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Chats.shown
            currentIndex: Chats.shown.findIndex(c => c.jid === Chats.jid)
            onCurrentIndexChanged: if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain)
            onTapped: root.picked()

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property bool current: row.modelData.jid === Chats.jid
                readonly property var last: row.modelData.last

                width: ListView.view.width
                height: 54
                radius: Style.r(8)
                color: row.current ? Style.surfaceActive : (hover.hovered ? Style.surfaceHover : "transparent")

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        Chats.select(row.modelData.jid);
                        row.ListView.view.tapped();
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Icon {
                            visible: row.modelData.group
                            text: "group"
                            size: 14
                            color: Style.muted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            font.family: Style.family
                            font.pixelSize: Style.row
                            font.weight: row.modelData.unread ? Font.DemiBold : Font.Medium
                            color: Style.text
                        }

                        Text {
                            text: Chats.stamp(row.modelData.ts)
                            font.family: Style.family
                            font.pixelSize: Style.tiny
                            color: row.modelData.unread ? Theme.accent : Style.muted
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Icon {
                            visible: !!row.last && !row.last.deleted && Chats.glyph(row.last.kind) !== ""
                            text: row.last ? Chats.glyph(row.last.kind) : ""
                            size: 13
                            color: Style.muted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                const l = row.last;
                                if (!l)
                                    return "";
                                const body = l.deleted ? "deleted message" : Chats.label(l.kind, l.text, "");
                                const who = l.me ? "You" : l.who;
                                return (who ? `${who}: ` : "") + body.replace(/\s+/g, " ");
                            }
                            elide: Text.ElideRight
                            font.family: Style.family
                            font.pixelSize: Style.body
                            font.italic: !!row.last && row.last.deleted
                            color: Style.dim
                        }

                        Icon {
                            visible: row.modelData.pinned
                            text: "keep"
                            size: 13
                            color: Style.muted
                        }

                        Icon {
                            visible: row.modelData.muted
                            text: "notifications_off"
                            size: 13
                            color: Style.muted
                        }

                        Count {
                            visible: row.modelData.unread > 0
                            text: row.modelData.unread
                            tint: row.modelData.muted ? Style.muted : Theme.accent
                        }
                    }
                }
            }
        }
    }
}
