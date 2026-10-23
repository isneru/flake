import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/singletons"
import "root:/components"
import "root:/store"

Item {
    id: root

    property alias list: view

    signal leave

    function write(): void {
        input.forceActiveFocus();
    }

    function submit(): void {
        Chats.send(input.text);
        input.text = "";
    }

    readonly property bool linked: Chats.state !== "logged-out" && (Chats.state !== "" || Chats.chats.length > 0)

    Connections {
        target: Chats
        function onJidChanged(): void {
            view.stick = true;
            input.text = "";
        }
        function onCompose(): void {
            input.forceActiveFocus();
        }
        function onTextPaste(): void {
            input.paste();
        }
        function onAttachmentsChanged(): void {
            if (Chats.attachments.length)
                prompt.forceActiveFocus();
            else if (prompt.activeFocus)
                root.leave();
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.linked || !Chats.chat

        Column {
            anchors.centerIn: parent
            spacing: 14

            Empty {
                glyph: root.linked ? "forum" : "link_off"
                title: !Chats.ready ? "" : root.linked ? "No chat open" : "Not linked"
                detail: root.linked ? "Pick a chat on the left, or / to search" : "Link this computer as a WhatsApp device"
            }

            Rectangle {
                visible: Chats.ready && !root.linked
                anchors.horizontalCenter: parent.horizontalCenter
                width: linkLabel.implicitWidth + 24
                height: 30
                radius: Style.r(8)
                color: linkHover.hovered ? Theme.accent : Style.surfaceActive

                HoverHandler {
                    id: linkHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: Quickshell.execDetached(["kitty", "--title", "WhatsApp login", "-e", "neru", "whatsapp", "login"])
                }

                Text {
                    id: linkLabel
                    anchors.centerIn: parent
                    text: "Link device"
                    font.family: Style.family
                    font.pixelSize: Style.body
                    font.weight: Font.Medium
                    color: linkHover.hovered ? Style.onAccent : Style.text
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.linked && !!Chats.chat
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.leftMargin: 18
            Layout.rightMargin: 12
            spacing: 10

            Icon {
                text: Chats.chat && Chats.chat.group ? "group" : "person"
                size: 20
                color: Style.dim
            }

            Column {
                Layout.fillWidth: true

                Text {
                    width: parent.width
                    text: Chats.chat ? Chats.chat.name : ""
                    elide: Text.ElideRight
                    font.family: Style.family
                    font.pixelSize: Style.title
                    font.weight: Font.DemiBold
                    color: Style.text
                }

                Text {
                    text: !Chats.chat ? "" : Chats.chat.group ? "group" : `+${Chats.jid.split("@")[0]}`
                    font.family: Style.family
                    font.pixelSize: Style.small
                    color: Style.muted
                }
            }

            Icon {
                visible: !!Chats.chat && Chats.chat.muted
                text: "notifications_off"
                size: 16
                color: Style.muted
            }

            IconButton {
                glyph: "folder_open"
                onActivated: Quickshell.execDetached(["xdg-open", `${Quickshell.env("HOME")}/.local/share/whatsapp/media/${Chats.jid.split("@")[0]}`])
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        ListView {
            id: view

            property bool stick: true
            property real lastY: 0

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            topMargin: 8
            bottomMargin: 8
            boundsBehavior: Flickable.StopAtBounds
            model: Chats.thread
            cacheBuffer: 1200

            delegate: Bubble {}

            function pin(): void {
                if (view.stick)
                    view.positionViewAtEnd();
            }

            onContentYChanged: {
                if (view.moving && view.contentY < view.lastY - 0.5)
                    view.stick = false;
                else if (view.contentY + view.height >= view.originY + view.contentHeight - 4)
                    view.stick = true;
                view.lastY = view.contentY;
            }
            onCountChanged: Qt.callLater(view.pin)
            onContentHeightChanged: Qt.callLater(view.pin)
        }

        Text {
            visible: !!Chats.error
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            text: Chats.error
            elide: Text.ElideRight
            font.family: Style.family
            font.pixelSize: Style.small
            color: Theme.error
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        Rectangle {
            visible: !!Chats.reply
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Theme.bgDim

            Rectangle {
                width: 2
                height: parent.height
                color: Theme.accent
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                spacing: 8

                Icon {
                    text: "reply"
                    size: 16
                    color: Theme.accent
                }

                Column {
                    Layout.fillWidth: true

                    Text {
                        width: parent.width
                        text: Chats.reply ? `Replying to ${Chats.reply.who}` : ""
                        elide: Text.ElideRight
                        font.family: Style.family
                        font.pixelSize: Style.tiny
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }

                    Text {
                        width: parent.width
                        text: Chats.reply ? Chats.reply.text.replace(/\s+/g, " ") : ""
                        elide: Text.ElideRight
                        font.family: Style.family
                        font.pixelSize: Style.small
                        color: Style.dim
                    }
                }

                IconButton {
                    glyph: "close"
                    onActivated: Chats.reply = null
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(input.contentHeight, 120) + 24
            color: input.activeFocus ? Theme.bg : Theme.bgDim

            IconButton {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                glyph: "attach_file"
                onActivated: Chats.pick()
            }

            Flickable {
                id: scroller
                anchors.fill: parent
                anchors.leftMargin: 46
                anchors.rightMargin: 18
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                contentHeight: input.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: input
                    width: scroller.width
                    wrapMode: TextEdit.Wrap
                    font.family: Style.family
                    font.pixelSize: Style.row
                    color: Style.text
                    selectionColor: Theme.accent
                    selectedTextColor: Style.onAccent
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < scroller.contentY)
                            scroller.contentY = cursorRectangle.y;
                        else if (cursorRectangle.y + cursorRectangle.height > scroller.contentY + scroller.height)
                            scroller.contentY = cursorRectangle.y + cursorRectangle.height - scroller.height;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.leave();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                            Chats.paste();
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            root.submit();
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.fill: parent
                        visible: !input.text
                        text: input.activeFocus ? "Message · Enter to send, Shift+Enter for a new line" : "i to write · o to attach a file · r to reply"
                        font: input.font
                        color: Style.faint
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: Chats.attachments.length > 0
        color: Theme.alpha(Theme.bg, 0.75)

        TapHandler {
            onTapped: {}
        }

        Rectangle {
            id: prompt

            readonly property string path: Chats.attachments.length ? Chats.attachments[0] : ""
            readonly property bool image: Chats.isImage(prompt.path)
            readonly property var choices: prompt.image ? [
                {
                    key: "s",
                    as: "sticker",
                    label: "Sticker"
                },
                {
                    key: "f",
                    as: "photo",
                    label: "Photo"
                },
                {
                    key: "d",
                    as: "document",
                    label: "File"
                }
            ] : [
                {
                    key: "↵",
                    as: "auto",
                    label: "Send"
                }
            ]

            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 440)
            height: card.implicitHeight + 36
            radius: Style.r(12)
            color: Theme.bgAlt
            border.color: Theme.border
            border.width: 1

            Keys.onPressed: event => {
                event.accepted = true;
                if (event.key === Qt.Key_Escape) {
                    Chats.attachments = Chats.attachments.slice(1);
                    return;
                }
                const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
                const hit = prompt.choices.find(c => enter ? c.key === "↵" : c.key === event.text);
                if (hit)
                    Chats.sendFile(prompt.path, hit.as);
            }

            ColumnLayout {
                id: card
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: Chats.attachments.length > 1 ? `Send to ${Chats.chat ? Chats.chat.name : ""} · ${Chats.attachments.length} files` : `Send to ${Chats.chat ? Chats.chat.name : ""}`
                    elide: Text.ElideRight
                    font.family: Style.family
                    font.pixelSize: Style.row
                    font.weight: Font.DemiBold
                    color: Style.text
                }

                AnimatedImage {
                    visible: prompt.image && status === Image.Ready
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(card.width, 260)
                    Layout.preferredHeight: implicitWidth > 0 ? Math.min(220, Layout.preferredWidth * implicitHeight / implicitWidth) : 0
                    source: prompt.image ? `file://${prompt.path}` : ""
                    fillMode: Image.PreserveAspectFit
                    playing: visible
                }

                RowLayout {
                    visible: !prompt.image
                    Layout.fillWidth: true
                    spacing: 8

                    Icon {
                        text: "description"
                        size: 22
                        color: Theme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: prompt.path.split("/").pop()
                        elide: Text.ElideMiddle
                        font.family: Style.family
                        font.pixelSize: Style.body
                        color: Style.text
                    }
                }

                Text {
                    visible: !!Chats.reply
                    Layout.fillWidth: true
                    text: Chats.reply ? `Replying to ${Chats.reply.who}` : ""
                    elide: Text.ElideRight
                    font.family: Style.family
                    font.pixelSize: Style.small
                    color: Theme.accent
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: prompt.choices

                        delegate: Rectangle {
                            id: choice

                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Style.r(8)
                            color: choiceHover.hovered ? Theme.accent : Style.surfaceActive

                            HoverHandler {
                                id: choiceHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Chats.sendFile(prompt.path, choice.modelData.as)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: `${choice.modelData.label} · ${choice.modelData.key}`
                                font.family: Style.family
                                font.pixelSize: Style.body
                                font.weight: Font.Medium
                                color: choiceHover.hovered ? Style.onAccent : Style.text
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Esc to skip"
                    horizontalAlignment: Text.AlignRight
                    font.family: Style.family
                    font.pixelSize: Style.tiny
                    color: Style.faint
                }
            }
        }
    }
}
