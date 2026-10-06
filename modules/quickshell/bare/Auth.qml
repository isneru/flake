import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    visible: Auth.pending
    color: Theme.alpha(Theme.bgDim, 0.55)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bare-auth"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) {
        field.text = "";
        field.forceActiveFocus();
    }

    Rectangle {
        anchors.centerIn: parent
        width: 460
        height: col.implicitHeight + 28
        radius: 0
        color: Theme.alpha(Theme.bgDim, 0.94)
        border.width: 1
        border.color: Theme.border

        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - 28
            spacing: 8

            Text {
                width: parent.width
                text: Auth.caption + (Auth.queue.length > 1 ? `  (+${Auth.queue.length - 1} waiting)` : "")
                color: Theme.accent
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize - 2
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: Auth.message
                visible: text !== ""
                wrapMode: Text.Wrap
                color: Theme.fg
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: Auth.detailLabel + "  " + Auth.detail
                visible: Auth.detail !== ""
                elide: Text.ElideRight
                color: Theme.fgMuted
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize - 2
                renderType: Text.NativeRendering
            }

            Rectangle {
                width: parent.width
                height: field.implicitHeight + 10
                visible: !Auth.confirming && !Auth.displaying
                radius: 0
                color: Theme.bg
                border.width: 1
                border.color: field.activeFocus ? Theme.accent : Theme.border

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.margins: 5
                    verticalAlignment: TextInput.AlignVCenter
                    enabled: Auth.inputEnabled
                    echoMode: Auth.echo ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "*"
                    color: Theme.fg
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize
                    renderType: Text.NativeRendering
                    onAccepted: root.submit()
                    Keys.onEscapePressed: Auth.cancel()
                }
            }

            Text {
                width: parent.width
                text: Auth.status
                visible: text !== ""
                wrapMode: Text.Wrap
                color: Auth.statusIsError ? Theme.ansiRed : Theme.fgDim
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize - 2
                renderType: Text.NativeRendering
            }

            Row {
                spacing: 10

                Text {
                    text: remember.on ? "[x] remember" : "[ ] remember"
                    visible: Auth.canRemember
                    color: Theme.fgDim
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize - 2
                    renderType: Text.NativeRendering

                    property bool on: false
                    id: remember

                    MouseArea {
                        anchors.fill: parent
                        onClicked: remember.on = !remember.on
                    }
                }
            }

            Row {
                spacing: 10

                Text {
                    text: "[Enter] " + Auth.confirmLabel
                    color: Theme.accent
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize - 2
                    renderType: Text.NativeRendering
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.submit()
                    }
                }

                Text {
                    text: "[Esc] " + Auth.denyLabel
                    color: Theme.fgMuted
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize - 2
                    renderType: Text.NativeRendering
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Auth.cancel()
                    }
                }
            }
        }

        Keys.onEscapePressed: Auth.cancel()
    }

    function submit() {
        if (Auth.confirming || Auth.displaying)
            Auth.confirm();
        else
            Auth.submit(field.text, remember.on);
        field.text = "";
        remember.on = false;
    }
}
