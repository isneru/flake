import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Item {
    id: root

    readonly property Flickable list: dueList
    readonly property var pending: Moodle.deadlines.filter(d => d.when > Date.now() / 1000 - 86400)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "Overview"
                font.family: Style.family
                font.pixelSize: Style.title
                font.weight: Font.DemiBold
                color: Style.text
            }

            Chip {
                visible: Moodle.shown.length > 0
                text: Moodle.shown.length + " courses"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Moodle.ready && Moodle.nextClass !== null
            spacing: 8

            Heading {
                text: Moodle.nextClass && Moodle.nextClass.start <= Moodle.now ? "NOW" : "NEXT CLASS"
            }

            ClassRow {
                Layout.fillWidth: true
                lecture: Moodle.nextClass
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Moodle.ready

            Empty {
                anchors.centerIn: parent
                glyph: "cloud_off"
                title: "Nothing synced yet"
                detail: "Run moodle login in a terminal, then press the refresh button."
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Moodle.ready
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 3
                spacing: 8

                Heading {
                    text: "UPCOMING"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.pending.length === 0

                    Empty {
                        anchors.centerIn: parent
                        glyph: "task_alt"
                        title: "Nothing due"
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.pending.length > 0

                    ListView {
                        id: dueList
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        model: root.pending
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: DeadlineRow {
                            required property var modelData
                            width: ListView.view.width
                            event: modelData
                        }
                    }

                    FastScroll {
                        view: dueList
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 2
                spacing: 8

                Heading {
                    text: "NOTIFICATIONS"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: Moodle.notices.length === 0

                    Empty {
                        anchors.centerIn: parent
                        glyph: "notifications_off"
                        title: "No notifications"
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: Moodle.notices.length > 0

                    ListView {
                        id: noticeList
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        model: Moodle.notices
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: notice

                            required property var modelData

                            width: ListView.view.width
                            height: body.implicitHeight + 22
                            radius: Style.r(Theme.rRow)
                            color: noticeHover.hovered ? Style.surfaceHover : Style.surface

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }

                            HoverHandler {
                                id: noticeHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Moodle.browse(notice.modelData.url)
                            }

                            Hint {
                                onActivated: Moodle.browse(notice.modelData.url)
                            }

                            ColumnLayout {
                                id: body
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        visible: !notice.modelData.read
                                        Layout.preferredWidth: 6
                                        Layout.preferredHeight: 6
                                        radius: Style.r(3)
                                        color: Theme.accent
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: notice.modelData.subject
                                        elide: Text.ElideRight
                                        font.family: Style.family
                                        font.pixelSize: Style.body
                                        font.weight: Font.Medium
                                        color: Style.text
                                    }

                                    Text {
                                        text: Moodle.stamp(notice.modelData.time)
                                        font.family: Style.family
                                        font.pixelSize: Style.tiny
                                        color: Style.faint
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: notice.modelData.text
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    font.family: Style.family
                                    font.pixelSize: Style.small
                                    color: Style.muted
                                }
                            }
                        }
                    }

                    FastScroll {
                        view: noticeList
                    }
                }
            }
        }
    }
}
