import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    property var lines: []
    property int anchor: 0
    property string image: ""

    visible: root.lines.length > 0
    color: "transparent"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bare-pop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) box.forceActiveFocus()

    function close(): void {
        root.lines = [];
        root.image = "";
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: box

        readonly property int pad: 10

        x: Math.round(Math.max(4, Math.min(parent.width - width - 4, root.anchor - width / 2)))
        y: parent.height - Mode.barHeight - height
        implicitWidth: col.implicitWidth + box.pad * 2
        implicitHeight: col.implicitHeight + box.pad
        width: implicitWidth
        height: implicitHeight
        radius: 0
        color: Theme.alpha(Theme.bgDim, 0.94)
        border.width: 1
        border.color: Theme.border
        focus: true

        Keys.onEscapePressed: root.close()

        Column {
            id: col
            anchors.centerIn: parent
            spacing: 2

            Image {
                visible: root.image !== ""
                source: root.image
                width: 240
                height: 240
                fillMode: Image.PreserveAspectFit
                smooth: false
                cache: false
            }

            Repeater {
                model: root.lines

                Text {
                    required property var modelData
                    text: modelData
                    color: Theme.fg
                    font.family: Theme.themeMono
                    font.pixelSize: Mode.barFont
                    renderType: Text.NativeRendering
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
        }
    }
}
