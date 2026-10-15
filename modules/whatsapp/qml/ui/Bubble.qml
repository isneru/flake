import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Item {
    id: root

    required property int index
    required property string key
    required property bool me
    required property string who
    required property real ts
    required property string kind
    required property string text
    required property string file
    required property string name
    required property real size
    required property string status
    required property bool edited
    required property bool deleted
    required property string quoteWho
    required property string quoteText
    required property string thumb
    required property real w
    required property real h

    readonly property Item box: bubble
    readonly property real cap: Math.min(560, root.width * 0.72)
    readonly property bool visual: (root.kind === "image" || root.kind === "sticker") && !root.deleted
    readonly property bool attached: (root.kind === "video" || root.kind === "audio" || root.kind === "document") && !root.deleted
    readonly property bool loading: !root.file && !!Chats.loading[root.key]
    readonly property bool media: !root.deleted && Chats.glyph(root.kind) !== "" && ["image", "sticker", "video", "audio", "document"].includes(root.kind)
    readonly property bool newDay: {
        const prev = root.index > 0 ? Chats.thread.get(root.index - 1) : null;
        return !prev || new Date(prev.ts).toDateString() !== new Date(root.ts).toDateString();
    }

    width: ListView.view.width
    height: column.implicitHeight

    HoverHandler {
        id: rowHover
    }

    function reply(): void {
        Chats.quote({
            key: root.key,
            me: root.me,
            who: root.who,
            kind: root.kind,
            text: root.text,
            name: root.name,
            deleted: root.deleted
        });
    }

    function save(): void {
        if (root.media)
            Chats.save(root.key);
    }

    function open(): void {
        if (root.visual && !root.file)
            Chats.load(root.key);
        else
            root.view();
    }

    function view(): void {
        Chats.openMedia({
            key: root.key,
            file: root.file
        });
    }

    function linkify(s: string): string {
        const escaped = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return escaped.replace(/(https?:\/\/[^\s<]+)/g, `<a href="$1" style="color:${Theme.accent}">$1</a>`).replace(/\n/g, "<br>");
    }

    Column {
        id: column
        width: parent.width
        topPadding: 3
        bottomPadding: 3
        spacing: 6

        Item {
            visible: root.newDay
            width: parent.width
            height: 30

            Rectangle {
                anchors.centerIn: parent
                width: dayLabel.implicitWidth + 16
                height: 20
                radius: Style.r(6)
                color: Style.surface

                Text {
                    id: dayLabel
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(root.ts), "dddd, d MMMM yyyy")
                    font.family: Style.family
                    font.pixelSize: Style.tiny
                    color: Style.muted
                }
            }
        }

        Rectangle {
            id: bubble
            x: root.me ? parent.width - width - 18 : 18

            Column {
                visible: rowHover.hovered && !root.deleted
                x: root.me ? -width - 6 : bubble.width + 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                IconButton {
                    glyph: "reply"
                    onActivated: root.reply()
                }

                IconButton {
                    visible: root.media
                    glyph: "save"
                    onActivated: root.save()
                }
            }

            width: Math.min(root.cap, Math.max(content.implicitWidth, 60) + 20)
            height: content.implicitHeight + 14
            radius: Style.r(10)
            color: root.me ? Theme.alpha(Theme.accent, 0.16) : Style.surface

            ColumnLayout {
                id: content
                x: 10
                y: 7
                width: bubble.width - 20
                spacing: 4

                Text {
                    visible: !!root.who
                    Layout.maximumWidth: root.cap - 20
                    text: root.who
                    elide: Text.ElideRight
                    font.family: Style.family
                    font.pixelSize: Style.small
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }

                Rectangle {
                    visible: !!root.quoteText
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.max(quoteWho.implicitWidth, quoteBody.implicitWidth) + 12
                    Layout.maximumWidth: root.cap - 20
                    implicitHeight: quote.implicitHeight + 8
                    color: Theme.alpha(Theme.bgDim, 0.6)

                    Rectangle {
                        width: 2
                        height: parent.height
                        color: Theme.accent
                    }

                    Column {
                        id: quote
                        x: 8
                        y: 4
                        width: parent.width - 12

                        Text {
                            id: quoteWho
                            width: parent.width
                            text: root.quoteWho
                            elide: Text.ElideRight
                            font.family: Style.family
                            font.pixelSize: Style.tiny
                            font.weight: Font.DemiBold
                            color: Style.dim
                        }

                        Text {
                            id: quoteBody
                            width: parent.width
                            text: root.quoteText
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            font.family: Style.family
                            font.pixelSize: Style.small
                            color: Style.muted
                        }
                    }
                }

                Item {
                    visible: root.visual
                    readonly property real limit: root.kind === "sticker" ? 160 : Math.min(320, root.cap - 20)
                    readonly property Image shown: root.kind === "sticker" ? motion : picture
                    readonly property bool ready: shown.status === Image.Ready && shown.implicitWidth > 0
                    readonly property real ratio: ready ? shown.implicitHeight / shown.implicitWidth : root.w > 0 && root.h > 0 ? root.h / root.w : 0.66
                    Layout.preferredWidth: ready ? Math.min(limit, shown.implicitWidth) : root.w > 0 ? Math.min(limit, root.w) : limit
                    Layout.preferredHeight: Math.min(Layout.preferredWidth * ratio, 420)

                    Image {
                        id: picture
                        anchors.fill: parent
                        visible: root.kind !== "sticker"
                        source: root.visual && root.kind !== "sticker" && root.file ? `file://${root.file}` : ""
                        sourceSize.width: 640
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }

                    AnimatedImage {
                        id: motion
                        anchors.fill: parent
                        visible: root.kind === "sticker"
                        source: root.kind === "sticker" && !root.deleted && root.file ? `file://${root.file}` : ""
                        fillMode: Image.PreserveAspectFit
                        playing: visible
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !parent.ready
                        color: Theme.alpha(Theme.bgDim, 0.6)
                        clip: true

                        Image {
                            anchors.fill: parent
                            visible: !!root.thumb
                            source: root.thumb
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 64
                            height: 52
                            radius: Style.r(8)
                            color: Theme.alpha(Theme.bg, 0.7)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loading || root.file ? "hourglass_empty" : "download"
                                size: 22
                                color: Style.muted
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loading || root.file ? "Loading" : root.size > 0 ? Chats.bytes(root.size) : "View"
                                font.family: Style.family
                                font.pixelSize: Style.tiny
                                color: Style.muted
                            }
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.open()
                    }
                }

                Rectangle {
                    visible: root.attached
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.min(root.cap - 20, Math.max(fileName.implicitWidth, 120) + 72)
                    implicitHeight: 44
                    color: fileHover.hovered ? Style.surfaceHover : Theme.alpha(Theme.bgDim, 0.6)

                    HoverHandler {
                        id: fileHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.open()
                    }

                    RowLayout {
                        id: attachment
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Icon {
                            text: Chats.glyph(root.kind)
                            size: 20
                            color: Theme.accent
                        }

                        Column {
                            Layout.fillWidth: true

                            Text {
                                id: fileName
                                width: parent.width
                                text: root.name || Chats.label(root.kind, "", "")
                                elide: Text.ElideMiddle
                                font.family: Style.family
                                font.pixelSize: Style.body
                                color: Style.text
                            }

                            Text {
                                text: Chats.bytes(root.size)
                                font.family: Style.family
                                font.pixelSize: Style.tiny
                                color: Style.muted
                            }
                        }

                        Icon {
                            text: root.loading ? "hourglass_empty" : root.file ? "open_in_new" : "download"
                            size: 16
                            color: Style.dim
                        }
                    }
                }

                Row {
                    visible: !root.attached && !root.visual && Chats.glyph(root.kind) !== "" && !root.deleted
                    spacing: 6

                    Icon {
                        text: Chats.glyph(root.kind)
                        size: 15
                        color: Style.dim
                    }

                    Text {
                        text: Chats.label(root.kind, "", "")
                        font.family: Style.family
                        font.pixelSize: Style.small
                        color: Style.dim
                    }
                }

                Text {
                    id: probe
                    visible: false
                    text: body.text
                    textFormat: Text.RichText
                    font: body.font
                }

                TextEdit {
                    id: body
                    visible: !!root.text || root.deleted
                    Layout.preferredWidth: Math.min(probe.implicitWidth + 1, root.cap - 20)
                    text: root.deleted ? "This message was deleted" : root.linkify(root.text)
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                    font.family: Style.family
                    font.pixelSize: Style.row
                    font.italic: root.deleted
                    color: root.deleted ? Style.muted : Style.text
                    selectionColor: Theme.accent
                    selectedTextColor: Style.onAccent
                    onLinkActivated: link => Qt.openUrlExternally(link)

                    HoverHandler {
                        cursorShape: body.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    Text {
                        text: (root.edited ? "edited · " : "") + Qt.formatDateTime(new Date(root.ts), "HH:mm")
                        font.family: Style.family
                        font.pixelSize: Style.tiny
                        color: Style.muted
                    }

                    Icon {
                        visible: root.me
                        text: root.status === "pending" ? "schedule" : root.status === "failed" ? "error" : root.status === "sent" ? "done" : "done_all"
                        size: 13
                        color: root.status === "read" ? Theme.accent : root.status === "failed" ? Theme.error : Style.muted
                    }
                }
            }
        }
    }
}
