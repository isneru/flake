import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    Component.onCompleted: Tray.refresh()

    component KillChip: Rectangle {
        id: chip
        required property string label
        required property color tone
        property bool armed: false
        signal confirmed

        implicitWidth: chipText.implicitWidth + 22
        implicitHeight: 28
        radius: 9
        color: armed ? tone : (chipHover.hovered ? Theme.s3 : Theme.s2)
        Behavior on color { ColorAnimation { duration: 160 } }

        HoverHandler { id: chipHover }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                if (chip.armed) {
                    chip.armed = false;
                    chip.confirmed();
                } else {
                    chip.armed = true;
                    disarm.restart();
                }
            }
        }
        Timer {
            id: disarm
            interval: 3000
            onTriggered: chip.armed = false
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.armed ? "Sure?" : chip.label
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            color: chip.armed ? Theme.fgOnAccent : Theme.t2
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "TRAY - STATUSNOTIFIER"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Tray.items.values.length + " item" + (Tray.items.values.length === 1 ? "" : "s")
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.t3
        }
        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 9
            color: refreshHover.hovered ? Theme.s3 : Theme.s2
            HoverHandler { id: refreshHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: Tray.refresh()
            }
            Icon {
                anchors.centerIn: parent
                size: 15
                text: "refresh"
                color: Tray.scanning ? Theme.accent : Theme.t2
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Tray.items.values.length > 0
        clip: true
        spacing: 8
        model: Tray.items
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property var proc: Tray.procFor(modelData.id)

            width: ListView.view.width
            height: 60
            radius: Theme.rCard
            color: Theme.s1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 13

                Image {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    source: row.modelData.icon
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Icon {
                    Layout.preferredWidth: 22
                    size: 20
                    filled: true
                    text: "widgets"
                    color: Theme.t3
                    visible: !row.modelData.icon
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: row.modelData.title || row.modelData.id || "unknown"
                        font.family: Theme.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.t1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: row.proc ? row.proc.name + " - pid " + row.proc.pid : "resolving…"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.t3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                KillChip {
                    label: "End"
                    tone: Theme.warning
                    visible: !!row.proc
                    onConfirmed: {
                        Tray.kill(row.proc.pid, false);
                        refreshSoon.restart();
                    }
                }
                KillChip {
                    label: "Force"
                    tone: Theme.error
                    visible: !!row.proc
                    onConfirmed: {
                        Tray.kill(row.proc.pid, true);
                        refreshSoon.restart();
                    }
                }
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 600
        onTriggered: Tray.refresh()
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Tray.items.values.length === 0

        Column {
            anchors.centerIn: parent
            spacing: 8
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 28
                text: "widgets"
                color: Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing in the tray"
                font.family: Theme.ui
                font.pixelSize: 12
                color: Theme.t3
            }
        }
    }
}
