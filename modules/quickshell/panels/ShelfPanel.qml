import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    Component.onCompleted: Shelf.probe()

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: Shelf.probe()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 30
        spacing: 10

        Text {
            text: "FILES SHELF"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Item { Layout.fillWidth: true }

        Rectangle {
            visible: Shelf.gone > 0
            Layout.preferredWidth: pruneLabel.implicitWidth + 26
            Layout.preferredHeight: 30
            radius: 15
            color: pruneHover.hovered ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            HoverHandler { id: pruneHover }
            TapHandler { onTapped: Shelf.pruneMissing() }
            Text {
                id: pruneLabel
                anchors.centerIn: parent
                text: "Drop " + Shelf.gone + " missing"
                font.family: Theme.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.warning
            }
        }

        Rectangle {
            Layout.preferredWidth: clearLabel.implicitWidth + 26
            Layout.preferredHeight: 30
            radius: 15
            color: clearHover.hovered ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            opacity: Shelf.count > 0 ? 1 : 0.4
            HoverHandler { id: clearHover }
            TapHandler {
                enabled: Shelf.count > 0
                onTapped: Shelf.clear()
            }
            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear"
                font.family: Theme.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: Theme.rCard
            visible: panelDrop.containsDrag
            color: Theme.alpha(Theme.success, 0.07)
            border.width: 1
            border.color: Theme.alpha(Theme.success, 0.45)
        }

        DropArea {
            id: panelDrop
            anchors.fill: parent
            onDropped: drop => {
                if (!drop.hasUrls)
                    return;
                drop.acceptProposedAction();
                Shelf.add(drop.urls);
            }
        }

        ListView {
            anchors.fill: parent
            visible: Shelf.count > 0
            clip: true
            spacing: 8
            model: Shelf.items
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: entry
                required property var modelData
                readonly property bool missing: modelData.state === "missing"

                width: ListView.view.width
                height: 60
                radius: Theme.rRow
                color: rowArea.containsMouse ? Theme.s3 : Theme.s1
                opacity: missing ? 0.55 : 1
                Behavior on color { ColorAnimation { duration: 160 } }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: entry.missing ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!entry.missing) Shelf.open(entry.modelData.path)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 10
                        clip: true
                        color: Theme.s2

                        Image {
                            anchors.fill: parent
                            visible: Shelf.isImage(entry.modelData)
                            source: Shelf.isImage(entry.modelData) ? Shelf.uri(entry.modelData.path) : ""
                            sourceSize.width: 76
                            sourceSize.height: 76
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !Shelf.isImage(entry.modelData)
                            size: 19
                            text: Shelf.iconFor(entry.modelData)
                            color: entry.missing ? Theme.warning : Theme.t2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: Shelf.name(entry.modelData.path)
                            font.family: Theme.ui
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.t1
                            elide: Text.ElideMiddle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.missing
                                ? "gone — " + Shelf.dir(entry.modelData.path)
                                : Shelf.dir(entry.modelData.path) + (Shelf.fmtSize(entry.modelData.size) ? " - " + Shelf.fmtSize(entry.modelData.size) : "")
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: entry.missing ? Theme.warning : Theme.t3
                            elide: Text.ElideMiddle
                        }
                    }

                    Repeater {
                        model: entry.missing ? [
                            { icon: "delete", act: "remove" }
                        ] : [
                            { icon: "forward", act: "send" },
                            { icon: "content_copy", act: "file" },
                            { icon: "link", act: "path" },
                            { icon: "folder_open", act: "reveal" },
                            { icon: "delete", act: "remove" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: btnArea.containsMouse ? Theme.s4 : "transparent"
                            Behavior on color { ColorAnimation { duration: 160 } }

                            Icon {
                                anchors.centerIn: parent
                                size: 16
                                text: parent.modelData.icon
                                color: btnArea.containsMouse ? Theme.t1 : Theme.t3
                            }

                            MouseArea {
                                id: btnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    switch (parent.modelData.act) {
                                    case "send": LocalSend.stage([entry.modelData.path]); NotchState.open("send"); break;
                                    case "file": Shelf.copyFile(entry.modelData.path); break;
                                    case "path": Shelf.copyPath(entry.modelData.path); break;
                                    case "reveal": Shelf.reveal(entry.modelData); break;
                                    case "remove": Shelf.remove(entry.modelData.path); break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: Shelf.count === 0
            spacing: 8
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 30
                text: "inbox"
                color: Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "The shelf is empty"
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "drag files onto the notch, or here"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: Shelf.count === 0
            ? "held by path - nothing is copied"
            : Shelf.count + (Shelf.count === 1 ? " item" : " items") + " - click to open"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
