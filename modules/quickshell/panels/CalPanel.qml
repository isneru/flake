import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

RowLayout {
    id: root
    spacing: 16

    readonly property date today: clock.date
    property int monthOffset: 0
    property date selected: clock.date
    property var detail: null
    property bool deleteArmed: false

    onSelectedChanged: root.detail = null
    onDetailChanged: root.deleteArmed = false

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property color tint: Theme.t1
        signal tapped

        implicitWidth: pillLabel.implicitWidth + 22
        implicitHeight: 28
        radius: 14
        color: pillHover.hovered ? Theme.alpha(pill.tint, 0.24) : Theme.alpha(pill.tint, 0.12)
        Behavior on color { ColorAnimation { duration: 160 } }

        HoverHandler { id: pillHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: pill.tapped()
        }

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.label
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            color: pill.tint
        }
    }

    function launch(url) {
        Agenda.launch(url);
        NotchState.close();
    }

    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

    readonly property int lead: (shown.getDay() + 6) % 7
    readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()

    readonly property var dayEvents: Agenda.eventsOn(selected)

    Component.onCompleted: Agenda.refresh()

    Timer {
        id: clock
        property date date: new Date()
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: date = new Date()
    }

    function dateAt(day) {
        return new Date(root.shown.getFullYear(), root.shown.getMonth(), day);
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 16
        color: Theme.s1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Qt.formatDateTime(root.shown, "MMMM yyyy")
                    font.family: Theme.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: Theme.t1
                }
                Item { Layout.fillWidth: true }
                RoundButton2 {
                    icon: "chevron_left"
                    onTapped: root.monthOffset--
                }
                RoundButton2 {
                    icon: "chevron_right"
                    onTapped: root.monthOffset++
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 4
                columnSpacing: 4

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    delegate: Text {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.preferredHeight: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.family: Theme.ui
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.t3
                    }
                }

                Repeater {
                    model: 42
                    delegate: Rectangle {
                        id: cell
                        required property int index
                        readonly property int day: index - root.lead + 1
                        readonly property bool inMonth: day >= 1 && day <= root.days
                        readonly property date date: root.dateAt(day)
                        readonly property bool today: inMonth && Agenda.sameDay(date, root.today)
                        readonly property bool picked: inMonth && Agenda.sameDay(date, root.selected)
                        readonly property var marks: inMonth ? Agenda.eventsOn(date).slice(0, 3) : []

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 9
                        color: today ? Theme.accent : picked ? Theme.s3 : hover.hovered && inMonth ? Theme.s2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 200 } }

                        HoverHandler { id: hover }
                        TapHandler {
                            enabled: cell.inMonth
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.selected = cell.date
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.marks.length ? -3 : 0
                            visible: cell.inMonth
                            text: cell.day
                            font.family: cell.today ? Theme.mono : Theme.ui
                            font.pixelSize: 12
                            color: cell.today ? Theme.fgOnAccent : Theme.t2
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            spacing: 3
                            Repeater {
                                model: cell.marks
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    color: cell.today ? Theme.fgOnAccent : modelData.color
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.preferredWidth: 255
        Layout.fillWidth: false
        Layout.fillHeight: true
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RoundButton2 {
                visible: !!root.detail
                icon: "chevron_left"
                onTapped: root.detail = null
            }
            Text {
                Layout.fillWidth: true
                text: root.detail
                    ? (root.detail.calendar || "EVENT").toUpperCase()
                    : (Agenda.sameDay(root.selected, root.today) ? "TODAY" : Qt.formatDateTime(root.selected, "ddd d MMM").toUpperCase())
                font.family: Theme.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.55
                color: Theme.t3
                elide: Text.ElideRight
            }
            Text {
                visible: !root.detail && root.dayEvents.length > 0
                text: root.dayEvents.length
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
            RoundButton2 {
                visible: !root.detail
                icon: Agenda.syncing ? "sync" : "refresh"
                onTapped: Agenda.refresh()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: Theme.s1
            clip: true

            Column {
                anchors.centerIn: parent
                visible: !root.detail && root.dayEvents.length === 0
                spacing: 8
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 26
                    text: Agenda.connected ? "event_available" : "link_off"
                    color: Theme.t4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Agenda.connected ? "Nothing scheduled" : "Not connected"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    color: Theme.t3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !Agenda.connected
                    text: "run gcal sync"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                }
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 8
                visible: !root.detail && root.dayEvents.length > 0
                interactive: false
                clip: true
                spacing: 2
                model: root.dayEvents

                delegate: Rectangle {
                    id: row
                    required property var modelData

                    width: list.width
                    height: body.implicitHeight + 16
                    radius: Theme.rRow
                    color: rowHover.hovered ? Theme.s2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 160 } }

                    HoverHandler { id: rowHover }
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.detail = row.modelData
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 3
                            Layout.fillHeight: true
                            radius: 1.5
                            color: row.modelData.color
                        }

                        ColumnLayout {
                            id: body
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: Agenda.span(row.modelData)
                                font.family: Theme.mono
                                font.pixelSize: 10
                                font.letterSpacing: 0.5
                                color: row.modelData.color
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                font.family: Theme.ui
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Theme.t1
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.location
                                font.family: Theme.ui
                                font.pixelSize: 11
                                color: Theme.t3
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    z: 10
                    onWheel: wheel => {
                        const max = Math.max(0, list.contentHeight - list.height);
                        list.contentY = Math.max(0, Math.min(max, list.contentY - wheel.angleDelta.y));
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                visible: !!root.detail
                spacing: 5

                Text {
                    Layout.fillWidth: true
                    text: root.detail ? Agenda.span(root.detail) : ""
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 0.5
                    color: root.detail?.color ?? Theme.accent
                }
                Text {
                    Layout.fillWidth: true
                    text: root.detail?.title ?? ""
                    font.family: Theme.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: Theme.t1
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: root.detail ? Qt.formatDateTime(new Date(root.detail.start), "dddd, d MMMM") : ""
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.t3
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: (root.detail?.location ?? "") !== ""
                    spacing: 6
                    Icon {
                        Layout.alignment: Qt.AlignTop
                        size: 14
                        text: "place"
                        color: Theme.t4
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.detail?.location ?? ""
                        font.family: Theme.ui
                        font.pixelSize: 11
                        color: Theme.t3
                        wrapMode: Text.Wrap
                    }
                }

                Flickable {
                    id: descFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 4
                    visible: (root.detail?.description ?? "") !== ""
                    contentHeight: desc.implicitHeight
                    interactive: false
                    clip: true

                    Text {
                        id: desc
                        width: descFlick.width
                        text: root.detail?.description ?? ""
                        font.family: Theme.ui
                        font.pixelSize: 11
                        color: Theme.alpha(Theme.t1, 0.5)
                        wrapMode: Text.Wrap
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        z: 10
                        onWheel: wheel => {
                            const max = Math.max(0, descFlick.contentHeight - descFlick.height);
                            descFlick.contentY = Math.max(0, Math.min(max, descFlick.contentY - wheel.angleDelta.y));
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                    visible: (root.detail?.description ?? "") === ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Pill {
                        visible: (root.detail?.meetLink ?? "") !== ""
                        label: "Join"
                        tint: Theme.success
                        onTapped: root.launch(root.detail.meetLink)
                    }
                    Pill {
                        visible: (root.detail?.link ?? "") !== ""
                        label: "Open"
                        onTapped: root.launch(root.detail.link)
                    }
                    Item { Layout.fillWidth: true }
                    Pill {
                        visible: root.detail?.writable ?? false
                        label: root.deleteArmed ? "Confirm?" : "Delete"
                        tint: root.deleteArmed ? Theme.error : Theme.t1
                        onTapped: {
                            if (!root.deleteArmed) {
                                root.deleteArmed = true;
                                return;
                            }
                            Agenda.remove(root.detail);
                            root.detail = null;
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            visible: !root.detail
            radius: 12
            color: Theme.s1
            border.width: 1
            border.color: addInput.activeFocus ? Theme.alpha(Theme.accent, 0.55) : "transparent"
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Icon {
                    size: 16
                    text: Agenda.writing ? "hourglass_top" : "add"
                    color: Theme.t3
                }
                TextInput {
                    id: addInput
                    Layout.fillWidth: true
                    enabled: !Agenda.writing
                    font.family: Theme.ui
                    font.pixelSize: 12
                    color: Theme.t1
                    selectionColor: Theme.accent
                    clip: true
                    onAccepted: {
                        Agenda.add(text);
                        text = "";
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: addInput.text === ""
                        text: "gym tomorrow 7pm"
                        font: addInput.font
                        color: Theme.t4
                    }
                }
            }
        }
    }
}
