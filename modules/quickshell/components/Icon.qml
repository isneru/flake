import QtQuick
import "root:/singletons"

Text {
    property real size: 20
    property bool filled: false
    property real weight: 350

    property bool crisp: true

    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: ({ FILL: filled ? 1 : 0, wght: weight, GRAD: 0, opsz: size })
    color: Theme.t1
    renderType: crisp ? Text.NativeRendering : Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
