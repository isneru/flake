import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    property var entries: []
    property string error: ""

    Process {
        id: list
        running: true
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l.trim());
                root.entries = rows.map(l => {
                    const tab = l.indexOf("\t");
                    return tab < 0
                        ? { id: "", preview: l }
                        : { id: l.slice(0, tab), preview: l.slice(tab + 1) };
                });
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }

    function run(cmd) {
        Quickshell.execDetached(cmd);
    }

    function copy(id) {
        run(["sh", "-c", "cliphist decode " + id + " | wl-copy"]);
        NotchState.close();
    }
    function remove(id) {
        run(["sh", "-c", "cliphist list | grep -m1 -P \"^$1\\t\" | cliphist delete", "sh", id]);
        refresh.restart();
    }
    function wipe() {
        run(["cliphist", "wipe"]);
        refresh.restart();
    }

    Timer {
        id: refresh
        interval: 250
        onTriggered: list.running = true
    }

    function swatch(s) {
        return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s.trim()) ? s.trim() : "";
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 30

        Text {
            text: "CLIPBOARD HISTORY"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            Layout.preferredWidth: wipeLabel.implicitWidth + 26
            Layout.preferredHeight: 30
            radius: 15
            color: wipeHover.hovered ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            opacity: root.entries.length > 0 ? 1 : 0.4
            HoverHandler { id: wipeHover }
            TapHandler {
                enabled: root.entries.length > 0
                onTapped: root.wipe()
            }
            Text {
                id: wipeLabel
                anchors.centerIn: parent
                text: "Wipe"
                font.family: Theme.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.entries.length > 0
        clip: true
        spacing: 8
        model: root.entries
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entry
            required property var modelData
            readonly property string swatch: root.swatch(modelData.preview)

            width: ListView.view.width
            height: 52
            radius: 12
            color: rowArea.containsMouse ? Theme.s3 : Theme.s1
            Behavior on color { ColorAnimation { duration: 160 } }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copy(entry.modelData.id)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 13

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: entry.swatch || Theme.s2
                    border.width: entry.swatch ? 1 : 0
                    border.color: Theme.hairline
                    Icon {
                        anchors.centerIn: parent
                        visible: !entry.swatch
                        size: 15
                        text: "content_paste"
                        color: Theme.t3
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: entry.modelData.preview
                    font.family: Theme.mono
                    font.pixelSize: 12
                    color: Theme.t1
                    elide: Text.ElideRight
                }
                Icon {
                    size: 17
                    text: "content_copy"
                    color: copyArea.containsMouse ? Theme.t1 : Theme.t3
                    MouseArea {
                        id: copyArea
                        anchors.fill: parent
                        anchors.margins: -7
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copy(entry.modelData.id)
                    }
                }
                Icon {
                    size: 17
                    text: "delete"
                    color: delArea.containsMouse ? Theme.error : Theme.t3
                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        anchors.margins: -7
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.remove(entry.modelData.id)
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.entries.length === 0

        Column {
            anchors.centerIn: parent
            spacing: 8
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 30
                text: "content_paste_off"
                color: Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.error ? "cliphist unavailable" : "Clipboard history is empty"
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.error || "copy something and it lands here"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "cliphist - " + root.entries.length + " entries"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
