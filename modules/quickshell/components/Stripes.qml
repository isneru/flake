import QtQuick
import "root:/singletons"

Rectangle {
    id: root
    property real strength: 0.12
    property string caption: ""

    radius: 8
    color: "transparent"

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.beginPath();
            ctx.roundedRect(0, 0, width, height, root.radius, root.radius);
            ctx.clip();

            ctx.fillStyle = Qt.rgba(1, 1, 1, root.strength * 0.3);
            ctx.fillRect(0, 0, width, height);
            ctx.strokeStyle = Qt.rgba(1, 1, 1, root.strength);
            ctx.lineWidth = 6;
            ctx.beginPath();
            for (let i = -height; i < width + height; i += 13) {
                ctx.moveTo(i, height);
                ctx.lineTo(i + height * 0.47, 0);
            }
            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onRadiusChanged() { canvas.requestPaint(); }
            function onStrengthChanged() { canvas.requestPaint(); }
        }
    }

    Text {
        visible: root.caption !== ""
        text: root.caption
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 7
        font.family: Theme.mono
        font.pixelSize: 10
        color: Theme.t3
    }
}
