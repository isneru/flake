import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Item {
    id: root

    readonly property Flickable list: hitList

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "Results for “" + Moodle.query.trim() + "”"
                elide: Text.ElideRight
                font.family: Style.family
                font.pixelSize: Style.title
                font.weight: Font.DemiBold
                color: Style.text
            }

            Chip {
                text: Moodle.hits.length + (Moodle.hits.length === 200 ? "+" : "") + " hits"
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Moodle.hits.length === 0

            Empty {
                anchors.centerIn: parent
                glyph: "search_off"
                title: "Nothing matched"
                detail: "Search covers every synced course, file name, page and announcement."
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Moodle.hits.length > 0

            ListView {
                id: hitList
                anchors.fill: parent
                clip: true
                spacing: 5
                model: Moodle.hits
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: hit

                    required property var modelData

                    width: ListView.view.width
                    height: hitBody.implicitHeight + 20
                    radius: Style.r(Theme.rRow)
                    color: hitHover.hovered ? Style.surfaceHover : Style.surface

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    HoverHandler {
                        id: hitHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    function primary(): void {
                        if (hit.modelData.path)
                            Moodle.open(hit.modelData.path);
                        else if (hit.modelData.courseId) {
                            Moodle.query = "";
                            Moodle.select(hit.modelData.courseId);
                        }
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: hit.primary()
                    }

                    Hint {
                        onActivated: hit.primary()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Icon {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 11
                            text: hit.modelData.path ? Moodle.fileIcon(hit.modelData.mime, hit.modelData.name) : Moodle.modIcon(hit.modelData.modname)
                            size: 17
                            color: Style.muted
                        }

                        ColumnLayout {
                            id: hitBody
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: hit.modelData.name
                                    elide: Text.ElideRight
                                    font.family: Style.family
                                    font.pixelSize: Style.row
                                    font.weight: Font.Medium
                                    color: Style.text
                                }

                                Chip {
                                    text: hit.modelData.course
                                    tint: Theme.accent
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: hit.modelData.text !== ""
                                text: hit.modelData.text
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                font.family: Style.family
                                font.pixelSize: Style.small
                                color: Style.muted
                            }
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 8
                            glyph: "open_in_new"
                            tint: Style.faint
                            onActivated: Moodle.browse(hit.modelData.url)
                        }
                    }
                }
            }

            FastScroll {
                view: hitList
            }
        }
    }
}
