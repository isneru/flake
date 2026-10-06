import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var presets: [
        { label: "1 min", secs: 60 },
        { label: "5 min", secs: 300 },
        { label: "10 min", secs: 600 },
        { label: "15 min", secs: 900 },
        { label: "25 min", secs: 1500 },
        { label: "45 min", secs: 2700 }
    ]

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 24

        Text {
            text: "TIMER"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: Countdown.rounds > 0
            text: Countdown.rounds + (Countdown.rounds === 1 ? " round done" : " rounds done")
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.success
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.rCard
        color: Theme.s1

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Countdown.active ? Countdown.title : "No timer running"
                font.family: Theme.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 0.4
                color: Countdown.kind === "break" ? Theme.success : (Countdown.active ? Theme.warning : Theme.t3)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Countdown.active ? Countdown.label : "0:00"
                font.family: Theme.mono
                font.pixelSize: 54
                font.weight: Font.Medium
                color: Countdown.active ? Theme.t1 : Theme.t4
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340
                height: 5
                radius: 3
                color: Theme.track
                Rectangle {
                    width: parent.width * Countdown.progress
                    height: parent.height
                    radius: parent.radius
                    color: Countdown.kind === "break" ? Theme.success : Theme.warning
                    Behavior on width { NumberAnimation { duration: 260 } }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Countdown.paused ? "paused" : (Countdown.active ? "ends " + Qt.formatDateTime(new Date(Countdown.endsAt), "HH:mm") : "pick a preset below")
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.t4
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 38
        spacing: 8

        Repeater {
            model: root.presets
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 12
                color: presetArea.containsMouse ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.t1
                }

                MouseArea {
                    id: presetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Countdown.start(parent.modelData.secs, "timer")
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 42
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 150
            Layout.preferredHeight: 42
            radius: 13
            color: Countdown.active ? (Countdown.paused ? Theme.warning : Theme.s3) : Theme.accent
            Behavior on color { ColorAnimation { duration: 160 } }
            opacity: mainArea.containsMouse ? 0.88 : 1

            Row {
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    filled: true
                    text: !Countdown.active ? "play_arrow" : (Countdown.paused ? "play_arrow" : "pause")
                    color: Countdown.active && !Countdown.paused ? Theme.t1 : Theme.fgOnAccent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !Countdown.active ? "Focus 25" : (Countdown.paused ? "Resume" : "Pause")
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Countdown.active && !Countdown.paused ? Theme.t1 : Theme.fgOnAccent
                }
            }

            MouseArea {
                id: mainArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Countdown.active ? Countdown.toggle() : Countdown.start(Countdown.focusSecs, "focus")
            }
        }

        Repeater {
            model: [
                { label: "+1 min", secs: 60 },
                { label: "+5 min", secs: 300 }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 13
                color: addArea.containsMouse ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }
                opacity: Countdown.active ? 1 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.t1
                }

                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Countdown.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Countdown.extend(parent.modelData.secs)
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 110
            Layout.preferredHeight: 42
            radius: 13
            color: stopArea.containsMouse ? Theme.alpha(Theme.error, 0.22) : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            opacity: Countdown.active ? 1 : 0.4

            Text {
                anchors.centerIn: parent
                text: "Stop"
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: stopArea.containsMouse ? Theme.error : Theme.t1
            }

            MouseArea {
                id: stopArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: Countdown.active
                cursorShape: Qt.PointingHandCursor
                onClicked: Countdown.stop()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "presets run once - Focus 25 alternates 25 min focus with 5 min breaks until stopped"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
