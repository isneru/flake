import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    readonly property var spec: NotchState.osd
    readonly property var payload: NotchState.osdData
    readonly property bool showing: NotchState.isOsd
    readonly property bool isNotif: NotchState.osdKind === "notif"

    readonly property string caption: payload.app ?? ""
    readonly property string headline: NotchState.osdKind === "shot" && payload.saved ? "Saved" : spec.label || payload.title || ""
    readonly property string detail: spec.sub || payload.body || payload.artist || ""

    visible: showing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.right: root.isNotif
    margins.top: Math.round((root.screen?.height ?? 1080) * 0.1)
    margins.right: root.isNotif ? 12 : 0
    implicitWidth: box.width
    implicitHeight: box.height

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bare-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: box

        width: 340
        height: col.implicitHeight + 16
        radius: 0
        color: root.spec.color
        border.width: 1
        border.color: root.spec.color

        HoverHandler {
            onHoveredChanged: NotchState.osdHovered = hovered
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 4

            Text {
                width: parent.width
                text: root.caption
                visible: text !== ""
                color: Theme.bg
                elide: Text.ElideRight
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize - 3
                renderType: Text.NativeRendering
            }

            Row {
                width: parent.width
                spacing: 10
                visible: root.headline !== ""

                Text {
                    id: head
                    width: parent.width - (save.visible ? save.width + parent.spacing : 0)
                    text: root.headline
                    color: Theme.bg
                    elide: Text.ElideRight
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize
                    renderType: Text.NativeRendering
                }

                Text {
                    id: save
                    anchors.baseline: head.baseline
                    text: "[save]"
                    visible: root.spec.save
                    color: Theme.bg
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize - 2
                    font.underline: saveArea.containsMouse
                    renderType: Text.NativeRendering

                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: NotchState.saveShot()
                    }
                }
            }

            Text {
                width: parent.width
                text: root.detail
                visible: text !== ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
                color: Theme.bg
                elide: Text.ElideRight
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize - 2
                renderType: Text.NativeRendering
            }

            Rectangle {
                width: parent.width
                height: 3
                visible: root.spec.bar
                color: Theme.alpha(Theme.bg, 0.25)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, root.spec.pct)) / 100
                    height: parent.height
                    color: Theme.bg
                }
            }
        }
    }
}
