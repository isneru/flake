import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

Scope {
    id: root
    required property var modelData

    component Corner: PanelWindow {
        id: win
        required property bool atTop
        required property bool atLeft

        screen: root.modelData
        color: "transparent"
        visible: !NotchState.hidden
        implicitWidth: Bezel.radius
        implicitHeight: Bezel.radius

        anchors.top: atTop
        anchors.bottom: !atTop
        anchors.left: atLeft
        anchors.right: !atLeft

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-corners"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            x: -1
            y: -1
            width: 1
            height: 1
        }

        Canvas {
            id: wedge
            anchors.fill: parent

            readonly property real cx: win.atLeft ? width : 0
            readonly property real cy: win.atTop ? height : 0

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.globalCompositeOperation = "source-over";
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "#000000";
                ctx.fillRect(0, 0, width, height);

                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(cx, cy, width, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    Corner { atTop: true;  atLeft: true }
    Corner { atTop: true;  atLeft: false }
    Corner { atTop: false; atLeft: true }
    Corner { atTop: false; atLeft: false }
}
