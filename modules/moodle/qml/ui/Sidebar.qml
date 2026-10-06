import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Rectangle {
    id: root

    color: Theme.bgDim

    signal done

    function focusSearch(): void {
        field.forceActiveFocus();
    }

    function dueCount(id: int): int {
        const now = Date.now() / 1000;
        return Moodle.deadlines.filter(d => d.courseId === id && d.when > now && d.when < now + 1209600).length;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                text: "school"
                size: 20
                color: Theme.accent
            }

            Text {
                Layout.fillWidth: true
                text: Moodle.user || "Moodle"
                elide: Text.ElideRight
                font.family: Style.family
                font.pixelSize: Style.row
                font.weight: Font.DemiBold
                color: Style.text
            }

            IconButton {
                glyph: "calendar_view_week"
                active: Moodle.courseId === 0 && Moodle.week
                onActivated: {
                    Moodle.week = true;
                    Moodle.courseId = 0;
                }
            }

            IconButton {
                glyph: "home"
                active: Moodle.courseId === 0 && !Moodle.week
                onActivated: {
                    Moodle.week = false;
                    Moodle.courseId = 0;
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
                    text: Moodle.query
                    onTextChanged: Moodle.query = text
                    font.family: Style.family
                    font.pixelSize: Style.body
                    color: Style.text
                    selectionColor: Theme.accent
                    selectedTextColor: Style.onAccent
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    Keys.onEscapePressed: {
                        Moodle.query = "";
                        root.done();
                    }
                    Keys.onReturnPressed: root.done()
                    Keys.onEnterPressed: root.done()

                    Text {
                        anchors.fill: parent
                        visible: !field.text
                        text: "Search everything"
                        font: field.font
                        color: Style.faint
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        ViewTabs {
            Layout.fillWidth: true
            current: Moodle.filter
            options: [
                {
                    key: "current",
                    label: "Current"
                },
                {
                    key: "past",
                    label: "Past"
                },
                {
                    key: "all",
                    label: "All"
                }
            ]
            onPicked: key => Moodle.filter = key
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: Moodle.shown
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: Moodle.shown.findIndex(c => c.id === Moodle.courseId)
            onCurrentIndexChanged: if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: entry

                required property var modelData
                readonly property bool active: Moodle.courseId === entry.modelData.id
                readonly property int pending: root.dueCount(entry.modelData.id)

                width: ListView.view.width
                height: 48
                radius: Style.r(Theme.rRow)
                color: entry.active ? Style.surfaceActive : (hover.hovered ? Style.surfaceHover : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: Moodle.select(entry.modelData.id)
                }

                Hint {
                    onActivated: Moodle.select(entry.modelData.id)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 22
                    radius: Style.r(2)
                    color: Theme.accent
                    opacity: entry.active ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8
                    opacity: entry.modelData.hidden ? 0.5 : 1

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Icon {
                                visible: entry.modelData.pinned
                                text: "push_pin"
                                size: 12
                                filled: true
                                color: Theme.warning
                            }

                            Icon {
                                visible: entry.modelData.hidden
                                text: "visibility_off"
                                size: 12
                                color: Style.faint
                            }

                            Text {
                                Layout.fillWidth: true
                                text: entry.modelData.shortname || entry.modelData.fullname
                                elide: Text.ElideRight
                                font.family: Style.family
                                font.pixelSize: Style.row
                                font.weight: Font.DemiBold
                                color: entry.active ? Style.text : Style.dim
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.fullname
                            elide: Text.ElideRight
                            font.family: Style.family
                            font.pixelSize: Style.small
                            color: Style.faint
                        }
                    }

                    Count {
                        visible: entry.pending > 0
                        text: String(entry.pending)
                        tint: Theme.warning
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: Moodle.syncing ? "Syncing..." : (Moodle.updated ? "Synced " + Moodle.stamp(Moodle.updated) : "Never synced")
                elide: Text.ElideRight
                font.family: Style.family
                font.pixelSize: Style.small
                color: Moodle.syncing ? Theme.accent : Style.faint
            }

            IconButton {
                glyph: "refresh"
                spinning: Moodle.syncing
                onActivated: Moodle.sync()
            }

            IconButton {
                glyph: "open_in_new"
                onActivated: Moodle.browse("")
            }
        }
    }
}
