import QtQuick

Text {
    property real size: 20
    property bool filled: false
    property string family: "Material Symbols Rounded"

    font.family: family
    font.pixelSize: size
    font.variableAxes: ({ FILL: filled ? 1 : 0, wght: 350, GRAD: 0, opsz: size })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
