import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Item {
    id: root

    readonly property var course: Moodle.course
    readonly property var detail: Moodle.detail
    readonly property var sections: root.detail && root.detail.sections ? root.detail.sections : []
    readonly property var grades: root.detail && root.detail.grades ? root.detail.grades : []
    readonly property var posts: root.detail && root.detail.announcements ? root.detail.announcements : []
    readonly property var assessments: Moodle.tasksOf(Moodle.courseId).concat(root.detail && root.detail.assessments ? root.detail.assessments : [])
    readonly property bool excluded: root.course && root.course.hidden ? true : false
    readonly property var lectures: Moodle.classesOf(Moodle.courseId)
    readonly property Flickable list: Moodle.tab === "content" ? contentList : Moodle.tab === "work" ? workList : Moodle.tab === "grades" ? gradeList : Moodle.tab === "classes" ? classList : Moodle.tab === "notes" ? noteList : newsList

    function step(n: int): void {
        const keys = tabs.options.map(o => o.key);
        Moodle.tab = keys[(keys.indexOf(Moodle.tab) + n + keys.length) % keys.length];
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: root.course ? root.course.fullname : ""
                    elide: Text.ElideRight
                    font.family: Style.family
                    font.pixelSize: Style.title
                    font.weight: Font.DemiBold
                    color: Style.text
                }

                IconButton {
                    glyph: "push_pin"
                    active: root.course && root.course.pinned
                    onActivated: Moodle.toggle("pin", Moodle.courseId, !(root.course && root.course.pinned))
                }

                IconButton {
                    glyph: root.course && root.course.hidden ? "visibility_off" : "visibility"
                    active: root.course && root.course.hidden
                    onActivated: Moodle.toggle("hide", Moodle.courseId, !(root.course && root.course.hidden))
                }

                IconButton {
                    glyph: "edit_note"
                    visible: root.course && root.course.home ? true : false
                    onActivated: Moodle.newNote()
                }

                IconButton {
                    glyph: "folder_open"
                    onActivated: Moodle.reveal((root.course && root.course.dir ? root.course.dir : "") + "/.")
                }

                IconButton {
                    glyph: "refresh"
                    spinning: Moodle.refreshing
                    onActivated: Moodle.refresh(Moodle.courseId)
                }

                IconButton {
                    glyph: "open_in_new"
                    onActivated: Moodle.browse(root.course ? root.course.url : "")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Chip {
                    visible: root.course && root.course.shortname
                    text: root.course ? root.course.shortname : ""
                    tint: Theme.accent
                }

                Chip {
                    visible: root.course && root.course.term
                    text: root.course ? root.course.term : ""
                }

                Chip {
                    visible: root.course && root.course.classification === "past"
                    text: "archived"
                    tint: Style.faint
                }

                Chip {
                    visible: root.course && root.course.files > 0
                    text: (root.course ? root.course.files : 0) + " files"
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        ViewTabs {
            id: tabs
            Layout.fillWidth: true
            current: Moodle.tab
            options: [
                {
                    key: "content",
                    label: "Content"
                },
                {
                    key: "notes",
                    label: "Notes"
                },
                {
                    key: "classes",
                    label: "Classes"
                },
                {
                    key: "work",
                    label: "Assessment"
                },
                {
                    key: "grades",
                    label: "Grades"
                },
                {
                    key: "news",
                    label: "Announcements"
                }
            ]
            onPicked: key => Moodle.tab = key
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Empty {
                anchors.centerIn: parent
                visible: !Moodle.detailReady && !root.excluded && Moodle.tab !== "classes" && Moodle.tab !== "notes"
                glyph: "hourglass_empty"
                title: "Fetching this course"
                detail: "It will appear here as soon as the first sync finishes."
            }

            Empty {
                anchors.centerIn: parent
                visible: root.excluded
                glyph: "visibility_off"
                title: "Excluded from sync"
                detail: "Nothing is mirrored for this course and its files were removed.\nUnhide it, then run a full sync to get it back."
            }

            ListView {
                id: contentList
                anchors.fill: parent
                visible: Moodle.detailReady && Moodle.tab === "content"
                clip: true
                spacing: 18
                model: root.sections
                boundsBehavior: Flickable.StopAtBounds

                delegate: ColumnLayout {
                    id: section

                    required property var modelData

                    width: ListView.view.width
                    spacing: 6

                    Heading {
                        text: String(section.modelData.name).toUpperCase()
                    }

                    Rich {
                        Layout.fillWidth: true
                        visible: section.modelData.html !== ""
                        text: section.modelData.html
                    }

                    Repeater {
                        model: section.modelData.modules

                        delegate: ModuleRow {
                            required property var modelData
                            Layout.fillWidth: true
                            module: modelData
                        }
                    }
                }
            }

            ListView {
                id: workList
                anchors.fill: parent
                visible: Moodle.detailReady && Moodle.tab === "work"
                clip: true
                spacing: 6
                model: root.assessments
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: work

                    required property var modelData
                    readonly property bool submitted: work.modelData.state === "submitted"

                    function primary(): void {
                        if (work.modelData.kind !== "deadline")
                            Moodle.browse(work.modelData.url);
                        else if (work.modelData.file)
                            Moodle.openNote(work.modelData.file);
                        else
                            Moodle.open(work.modelData.url);
                    }

                    width: ListView.view.width
                    height: 58
                    radius: Style.r(Theme.rRow)
                    color: workHover.hovered ? Style.surfaceHover : Style.surface

                    HoverHandler {
                        id: workHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: work.primary()
                    }

                    Hint {
                        onActivated: work.primary()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Icon {
                            text: Moodle.modIcon(work.modelData.kind)
                            size: 18
                            color: Style.muted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: work.modelData.name
                                elide: Text.ElideRight
                                font.family: Style.family
                                font.pixelSize: Style.row
                                font.weight: Font.Medium
                                color: Style.text
                            }

                            Text {
                                Layout.fillWidth: true
                                text: work.modelData.due ? "due " + Moodle.stamp(work.modelData.due) : "no due date"
                                elide: Text.ElideRight
                                font.family: Style.family
                                font.pixelSize: Style.small
                                color: Style.faint
                            }
                        }

                        Chip {
                            visible: work.modelData.state !== ""
                            text: work.modelData.state
                            tint: work.submitted ? Theme.success : Theme.warning
                        }

                        Text {
                            visible: work.modelData.due > 0
                            text: Moodle.due(work.modelData.due)
                            font.family: Style.family
                            font.pixelSize: Style.body
                            font.weight: Font.DemiBold
                            color: work.modelData.due - Date.now() / 1000 < 172800 ? Theme.warning : Style.muted
                        }
                    }
                }
            }

            ListView {
                id: gradeList
                anchors.fill: parent
                visible: Moodle.detailReady && Moodle.tab === "grades"
                clip: true
                spacing: 4
                model: root.grades
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: grade

                    required property var modelData

                    width: ListView.view.width
                    height: gradeBody.implicitHeight + 20
                    radius: Style.r(Theme.rRow)
                    color: Style.surface

                    ColumnLayout {
                        id: gradeBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: grade.modelData.name
                                elide: Text.ElideRight
                                font.family: Style.family
                                font.pixelSize: Style.row
                                color: Style.text
                            }

                            Text {
                                visible: grade.modelData.weight !== ""
                                text: grade.modelData.weight
                                font.family: Style.family
                                font.pixelSize: Style.small
                                color: Style.faint
                            }

                            Text {
                                text: grade.modelData.grade || "—"
                                font.family: Style.monoFamily
                                font.pixelSize: Style.row
                                font.weight: Font.DemiBold
                                color: grade.modelData.grade ? Theme.accent : Style.faint
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: grade.modelData.feedback !== ""
                            text: grade.modelData.feedback
                            wrapMode: Text.WordWrap
                            font.family: Style.family
                            font.pixelSize: Style.small
                            color: Style.muted
                        }
                    }
                }
            }

            ListView {
                id: newsList
                anchors.fill: parent
                visible: Moodle.detailReady && Moodle.tab === "news"
                clip: true
                spacing: 8
                model: root.posts
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: post

                    required property var modelData
                    property bool open: false

                    width: ListView.view.width
                    height: postBody.implicitHeight + 22
                    radius: Style.r(Theme.rRow)
                    color: postHover.hovered || post.open ? Style.surfaceHover : Style.surface

                    HoverHandler {
                        id: postHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: post.open = !post.open
                    }

                    Hint {
                        onActivated: post.open = !post.open
                    }

                    ColumnLayout {
                        id: postBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 11
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: post.modelData.subject
                                elide: Text.ElideRight
                                font.family: Style.family
                                font.pixelSize: Style.row
                                font.weight: Font.Medium
                                color: Style.text
                            }

                            Text {
                                text: post.modelData.author
                                font.family: Style.family
                                font.pixelSize: Style.small
                                color: Style.faint
                            }

                            Text {
                                text: Moodle.stamp(post.modelData.time)
                                font.family: Style.family
                                font.pixelSize: Style.tiny
                                color: Style.faint
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !post.open
                            text: post.modelData.text
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            font.family: Style.family
                            font.pixelSize: Style.body
                            color: Style.muted
                        }

                        Rich {
                            Layout.fillWidth: true
                            visible: post.open
                            text: post.modelData.html
                        }
                    }
                }
            }

            Empty {
                anchors.centerIn: parent
                visible: Moodle.tab === "classes" && root.lectures.length === 0
                glyph: "event_busy"
                title: "No classes scheduled"
                detail: "Classes come from Google Calendar events titled with this course's code."
            }

            ListView {
                id: classList
                anchors.fill: parent
                visible: Moodle.tab === "classes"
                clip: true
                spacing: 6
                model: root.lectures
                boundsBehavior: Flickable.StopAtBounds

                delegate: ClassRow {
                    required property var modelData
                    width: ListView.view.width
                    lecture: modelData
                    showCourse: false
                }
            }

            Empty {
                anchors.centerIn: parent
                visible: Moodle.tab === "notes" && !root.excluded && Moodle.notes.length === 0
                glyph: "edit_note"
                title: "No notes yet"
                detail: "Press n to start one for today."
            }

            ListView {
                id: noteList
                anchors.fill: parent
                visible: Moodle.tab === "notes"
                clip: true
                spacing: 2
                model: Moodle.notes
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: note

                    required property var modelData

                    width: ListView.view.width
                    height: 34
                    radius: Style.r(9)
                    color: noteHover.hovered ? Style.surfaceHover : "transparent"

                    HoverHandler {
                        id: noteHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: Moodle.openNote(note.modelData.path)
                    }

                    Hint {
                        onActivated: Moodle.openNote(note.modelData.path)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Icon {
                            text: "description"
                            size: 16
                            color: Style.muted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: note.modelData.name
                            elide: Text.ElideMiddle
                            font.family: Style.family
                            font.pixelSize: Style.body
                            color: Style.dim
                        }

                        Text {
                            text: note.modelData.day
                            font.family: Style.monoFamily
                            font.pixelSize: Style.tiny
                            color: Style.faint
                        }
                    }
                }
            }

            FastScroll {
                view: root.list
            }
        }
    }
}
