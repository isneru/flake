import QtQuick
import "root:/singletons"

Item {
    id: root

    property real pillW: 196
    readonly property real pillH: NotchState.collapsedH
    readonly property real pillY: NotchState.topMargin
    readonly property real pillR: Theme.rCollapsed
    readonly property real pillTopR: Config.pillStyle === "notch" ? 0 : Theme.rCollapsed

    readonly property real wT: Lock.wp
    readonly property real hT: Lock.hp
    readonly property real rT: Math.max(0, 1 - hT)

    Component.onCompleted: pillW = NotchState.surfaceW

    Rectangle {
        width: root.pillW + (root.width - root.pillW) * root.wT
        height: root.pillH + (root.height - root.pillH) * root.hT
        x: (root.width - width) / 2
        y: root.pillY * root.rT

        topLeftRadius: root.pillTopR * root.rT
        topRightRadius: root.pillTopR * root.rT
        bottomLeftRadius: root.pillR * root.rT
        bottomRightRadius: root.pillR * root.rT

        color: Config.pillStyle === "notch" && root.hT < 0.5 ? Theme.notchSolid : Theme.notchGlass
    }
}
