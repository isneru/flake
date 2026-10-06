import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

Item {
    id: root

    readonly property var req: LocalSend.ask
    readonly property var live: LocalSend.running
    readonly property bool busy: req === null && live !== null

    property string hoverId: ""
    property point hoverAt: Qt.point(0, 0)
    readonly property var hoverFile: (req?.files ?? []).find(f => f.id === hoverId) ?? null

    onReqChanged: hoverId = ""

    readonly property bool isMessage: (req?.count ?? 0) === 1 && (req?.files[0]?.preview ?? "") !== ""

    function subtitle(r) {
        if (isMessage)
            return "sent you a message";
        return r?.count === 1 ? "wants to send you a file"
                              : "wants to send you " + (r?.count ?? 0) + " files";
    }


    ColumnLayout {
        anchors.fill: parent
        visible: root.req !== null
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: 23
                color: Theme.alpha(Theme.accent, 0.16)

                Icon {
                    anchors.centerIn: parent
                    size: 24
                    text: LocalSend.deviceIcon(root.req?.deviceType ?? "")
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.req?.alias ?? ""
                    font.family: Theme.ui
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    color: Theme.t1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.subtitle(root.req)
                        font.family: Theme.ui
                        font.pixelSize: 13
                        color: Theme.t2
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: LocalSend.fmtSize(root.req?.total ?? 0)
                        font.family: Theme.mono
                        font.pixelSize: 12
                        color: Theme.t3
                    }
                }
            }
        }

        Rectangle {
            visible: root.isMessage
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: Theme.s1

            Text {
                anchors.fill: parent
                anchors.margins: 16
                text: root.req?.files[0]?.preview ?? ""
                font.family: Theme.mono
                font.pixelSize: 13
                color: Theme.t1
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: !root.isMessage
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: Theme.s1

            HoverHandler {
                onHoveredChanged: if (!hovered) root.hoverId = ""
            }

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                contentHeight: rows.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rows
                    width: flick.width
                    spacing: 2

                    Repeater {
                        model: root.req?.files ?? []

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            width: rows.width
                            height: 38
                            radius: 11
                            color: hov.hovered ? Theme.s3 : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }

                            HoverHandler {
                                id: hov
                                onHoveredChanged: {
                                    if (hovered)
                                        root.hoverId = row.modelData.id;
                                    else if (root.hoverId === row.modelData.id)
                                        root.hoverId = "";
                                }
                                onPointChanged: {
                                    if (!hovered)
                                        return;
                                    root.hoverAt = row.mapToItem(root, point.position.x, point.position.y);
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Icon {
                                    size: 17
                                    text: LocalSend.fileIcon(row.modelData)
                                    color: Theme.t2
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    font.family: Theme.ui
                                    font.pixelSize: 13
                                    color: Theme.t1
                                    elide: Text.ElideMiddle
                                }
                                Text {
                                    text: LocalSend.fmtSize(row.modelData.size)
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    color: Theme.t3
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "saving to  " + LocalSend.dest
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.t4
                elide: Text.ElideMiddle
            }

            Rectangle {
                Layout.preferredWidth: 118
                Layout.preferredHeight: 42
                radius: 13
                color: declineArea.containsMouse ? Theme.alpha(Theme.error, 0.22) : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }

                Text {
                    anchors.centerIn: parent
                    text: "Decline"
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: declineArea.containsMouse ? Theme.error : Theme.t1
                }

                MouseArea {
                    id: declineArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.deny(root.req?.id ?? "")
                }
            }

            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 42
                radius: 13
                color: Theme.accent
                opacity: acceptArea.containsMouse ? 0.88 : 1

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        filled: true
                        text: "download"
                        color: Theme.fgOnAccent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Accept"
                        font.family: Theme.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.fgOnAccent
                    }
                }

                MouseArea {
                    id: acceptArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.accept(root.req?.id ?? "")
                }
            }
        }
    }


    ColumnLayout {
        anchors.fill: parent
        visible: root.busy
        spacing: 14

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.live?.dir === "in" ? "Receiving files" : "Sending files"
            font.family: Theme.ui
            font.pixelSize: 17
            font.weight: Font.Medium
            color: Theme.t1
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: (root.live?.dir === "in" ? "from " : "to ") + (root.live?.peer ?? "")
            font.family: Theme.ui
            font.pixelSize: 12
            color: Theme.t3
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            Layout.topMargin: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: (root.live?.name ?? "") + "    " + (root.live?.index ?? 0) + "/" + (root.live?.count ?? 0)
                    font.family: Theme.ui
                    font.pixelSize: 12
                    color: Theme.t2
                    elide: Text.ElideMiddle
                }
                Text {
                    text: LocalSend.fmtSize(root.live?.sent ?? 0) + "  /  " + LocalSend.fmtSize(root.live?.total ?? 0)
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.t3
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.track

                Rectangle {
                    width: parent.width * Math.min(1, (root.live?.sent ?? 0) / Math.max(1, root.live?.total ?? 1))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 220 } }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                text: root.live?.state === "asking"
                    ? "waiting for " + (root.live?.peer ?? "") + " to accept"
                    : Math.floor(100 * (root.live?.sent ?? 0) / Math.max(1, root.live?.total ?? 1)) + "%"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.t4
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            width: 118
            height: 38
            radius: 13
            color: cancelArea.containsMouse ? Theme.alpha(Theme.error, 0.22) : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }

            Text {
                anchors.centerIn: parent
                text: "Cancel"
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: cancelArea.containsMouse ? Theme.error : Theme.t1
            }

            MouseArea {
                id: cancelArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: LocalSend.cancel(root.live?.id ?? "")
            }
        }

        Item { Layout.fillHeight: true }
    }


    ColumnLayout {
        anchors.fill: parent
        visible: root.req === null && !root.busy
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "SELECTION"
                font.family: Theme.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.55
                color: Theme.t3
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: LocalSend.compose === ""
                text: "Files: " + LocalSend.outbox.length + "    Size: " + LocalSend.fmtSize(LocalSend.outboxBytes)
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.t4
            }
            Text {
                visible: LocalSend.compose !== ""
                text: "a message, " + LocalSend.compose.length + " characters"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.t4
            }
            Rectangle {
                visible: !LocalSend.alive
                Layout.preferredWidth: 1
                Layout.preferredHeight: 11
                color: Theme.hairline
            }
            Text {
                visible: !LocalSend.alive
                text: "daemon not running"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.warning
            }
        }

        RowLayout {
            id: sources
            readonly property int lead: Math.round((root.width - spacing) * 0.6)
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: sources.lead
                Layout.preferredHeight: 52
                radius: Theme.rCard
                color: shelfArea.containsMouse ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 9
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 19
                        text: "inbox"
                        color: Theme.accent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Import from Shelf"
                        font.family: Theme.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.t1
                    }
                }

                MouseArea {
                    id: shelfArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.stageShelf()
                }
            }

            Rectangle {
                Layout.preferredWidth: root.width - sources.spacing - sources.lead
                Layout.preferredHeight: 52
                radius: Theme.rCard
                color: pasteArea.containsMouse ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 9
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 19
                        text: "content_paste"
                        color: Theme.accent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Paste"
                        font.family: Theme.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.t1
                    }
                }

                MouseArea {
                    id: pasteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.paste()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Theme.rCard
            color: selDrop.containsDrag ? Theme.alpha(Theme.accent, 0.1) : Theme.s1
            border.width: selDrop.containsDrag ? 1 : 0
            border.color: Theme.alpha(Theme.accent, 0.45)

            DropArea {
                id: selDrop
                anchors.fill: parent
                onDropped: drop => {
                    if (!drop.hasUrls)
                        return;
                    drop.acceptProposedAction();
                    LocalSend.stage(drop.urls);
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !LocalSend.armed
                text: "Place items to share, or drop them here"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.t4
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                visible: LocalSend.armed
                spacing: 8

                Text {
                    visible: LocalSend.compose !== ""
                    Layout.fillWidth: true
                    text: LocalSend.compose
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.t1
                    elide: Text.ElideRight
                }

                Flickable {
                    visible: LocalSend.compose === ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    contentWidth: chips.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: chips
                        height: 26
                        spacing: 6

                        Repeater {
                            model: LocalSend.outbox

                            delegate: Rectangle {
                                id: chip
                                required property string modelData
                                width: chipRow.width + 20
                                height: 26
                                radius: Theme.rRow
                                color: chipArea.containsMouse ? Theme.s3 : Theme.s2

                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 7

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: LocalSend.name(chip.modelData)
                                        font.family: Theme.ui
                                        font.pixelSize: 11
                                        color: Theme.t1
                                    }
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 13
                                        text: "close"
                                        color: chipArea.containsMouse ? Theme.error : Theme.t3
                                    }
                                }

                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: LocalSend.unstage(chip.modelData)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 26
                    radius: Theme.rRow
                    color: clearArea.containsMouse ? Theme.s3 : Theme.s2
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Delete all"
                        font.family: Theme.ui
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.t1
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { LocalSend.clearOutbox(); LocalSend.clearCompose(); }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 10

            Text {
                text: "NEARBY DEVICES"
                font.family: Theme.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.55
                color: Theme.t3
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: scanArea.containsMouse ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }

                Icon {
                    id: scanIcon
                    anchors.centerIn: parent
                    size: 16
                    text: "refresh"
                    color: Theme.t2

                    RotationAnimation on rotation {
                        running: LocalSend.scanning
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                        onRunningChanged: if (!running) scanIcon.rotation = 0
                    }
                }

                MouseArea {
                    id: scanArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: LocalSend.alive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.scan()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                cellWidth: Math.floor(width / 3)
                cellHeight: 76
                model: LocalSend.peers

                delegate: Item {
                    id: cellWrap
                    required property var modelData
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 8
                        radius: Theme.rCard
                        color: cardDrop.containsDrag ? Theme.alpha(Theme.accent, 0.16)
                            : (LocalSend.armed && cardArea.containsMouse ? Theme.s3 : Theme.s1)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        border.width: cardDrop.containsDrag ? 1 : 0
                        border.color: Theme.alpha(Theme.accent, 0.5)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Icon {
                                    size: 19
                                    text: LocalSend.deviceIcon(cellWrap.modelData.deviceType)
                                    color: Theme.accent
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: cellWrap.modelData.alias
                                    font.family: Theme.ui
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: Theme.t1
                                    elide: Text.ElideRight
                                }
                                Icon {
                                    visible: LocalSend.armed
                                    size: 16
                                    text: "forward"
                                    color: cardArea.containsMouse ? Theme.accent : Theme.t3
                                }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: cellWrap.modelData.ip
                                    font.family: Theme.mono
                                    font.pixelSize: 10
                                    color: Theme.t3
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    text: cellWrap.modelData.deviceModel || cellWrap.modelData.deviceType
                                    font.family: Theme.mono
                                    font.pixelSize: 10
                                    color: Theme.t4
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: LocalSend.armed
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LocalSend.sendTo(cellWrap.modelData)
                        }

                        DropArea {
                            id: cardDrop
                            anchors.fill: parent
                            onDropped: drop => {
                                if (!drop.hasUrls)
                                    return;
                                drop.acceptProposedAction();
                                LocalSend.sendPaths(cellWrap.modelData, drop.urls);
                            }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: LocalSend.peers.length === 0
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No devices yet"
                    font.family: Theme.ui
                    font.pixelSize: 13
                    color: Theme.t3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "make sure the other device is on the same Wi-Fi network"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                }
            }
        }
    }


    Rectangle {
        id: card
        visible: root.hoverFile !== null
        z: 100
        width: Math.min(340, Math.max(190, detail.implicitWidth + 26))
        height: detail.implicitHeight + 22
        radius: 13
        color: Theme.notchGlass
        border.width: 1
        border.color: Theme.hairline

        x: root.hoverAt.x + 16 + width > root.width
            ? Math.max(0, root.hoverAt.x - 16 - width)
            : root.hoverAt.x + 16
        y: root.hoverAt.y + 18 + height > root.height
            ? Math.max(0, root.hoverAt.y - 18 - height)
            : root.hoverAt.y + 18

        readonly property var rows: {
            const f = root.hoverFile;
            if (!f)
                return [];
            const out = [
                { k: "filename", v: f.name },
                { k: "type", v: f.type || "unknown" },
                { k: "size", v: LocalSend.fmtSize(f.size) }
            ];
            if (f.modified)
                out.push({ k: "modified", v: LocalSend.fmtWhen(f.modified) });
            return out;
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.s3
        }

        ColumnLayout {
            id: detail
            anchors.fill: parent
            anchors.margins: 11
            spacing: 3

            Repeater {
                model: card.rows

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 18

                    Text {
                        text: modelData.k + ":"
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.t4
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: modelData.v
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.t1
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
