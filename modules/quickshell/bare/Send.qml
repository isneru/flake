import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    readonly property var req: LocalSend.ask
    readonly property var files: req?.files ?? []
    readonly property bool isMessage: files.length === 1 && (files[0]?.preview ?? "") !== ""
    readonly property int shown: 6

    visible: req !== null
    color: Theme.alpha(Theme.bgDim, 0.55)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bare-send"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) card.forceActiveFocus()

    function accept(): void {
        if (root.req)
            LocalSend.accept(root.req.id);
    }

    function deny(): void {
        if (root.req)
            LocalSend.deny(root.req.id);
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 520
        height: col.implicitHeight + 28
        radius: 0
        color: Theme.alpha(Theme.bgDim, 0.94)
        border.width: 1
        border.color: Theme.border
        focus: true

        Keys.onReturnPressed: root.accept()
        Keys.onEnterPressed: root.accept()
        Keys.onEscapePressed: root.deny()

        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - 28
            spacing: 8

            Text {
                width: parent.width
                text: "RECEIVE  [" + (root.req?.alias || "unknown") + "]"
                    + (LocalSend.incoming.length > 1 ? `  (+${LocalSend.incoming.length - 1} waiting)` : "")
                elide: Text.ElideRight
                color: Theme.accent
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize - 2
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: root.isMessage
                    ? "sent you a message"
                    : `wants to send you ${root.files.length === 1 ? "a file" : root.files.length + " files"} (${LocalSend.fmtSize(root.req?.total ?? 0)})`
                wrapMode: Text.Wrap
                color: Theme.fg
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                visible: root.isMessage
                text: root.files[0]?.preview ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 8
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize
                renderType: Text.NativeRendering
            }

            Repeater {
                model: root.isMessage ? [] : root.files.slice(0, root.shown)

                Item {
                    required property var modelData
                    width: col.width
                    height: name.implicitHeight

                    Text {
                        id: name
                        anchors.left: parent.left
                        anchors.right: size.left
                        anchors.rightMargin: 12
                        text: `"${modelData.name}"`
                        elide: Text.ElideMiddle
                        color: Theme.fgDim
                        font.family: Theme.themeMono
                        font.pixelSize: Theme.themeSize - 2
                        renderType: Text.NativeRendering
                    }

                    Text {
                        id: size
                        anchors.right: parent.right
                        text: LocalSend.fmtSize(modelData.size ?? 0)
                        color: Theme.fgMuted
                        font.family: Theme.themeMono
                        font.pixelSize: Theme.themeSize - 2
                        renderType: Text.NativeRendering
                    }
                }
            }

            Text {
                width: parent.width
                visible: !root.isMessage && root.files.length > root.shown
                text: `(+${root.files.length - root.shown} more)`
                color: Theme.fgMuted
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize - 2
                renderType: Text.NativeRendering
            }

            Row {
                spacing: 10

                Text {
                    text: "[Enter] accept"
                    color: Theme.accent
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize - 2
                    renderType: Text.NativeRendering
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.accept()
                    }
                }

                Text {
                    text: "[Esc] decline"
                    color: Theme.fgMuted
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize - 2
                    renderType: Text.NativeRendering
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.deny()
                    }
                }
            }
        }
    }
}
