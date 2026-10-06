pragma Singleton
import QtQuick
import Quickshell
import "root:/singletons"

Singleton {
    id: root

    readonly property bool bare: Persist.bare

    readonly property string family: root.bare ? Theme.themeMono : Theme.ui
    readonly property string monoFamily: root.bare ? Theme.themeMono : Theme.mono

    readonly property int title: 19
    readonly property int row: 13
    readonly property int body: 12
    readonly property int small: 11
    readonly property int tiny: 10

    readonly property color text: root.bare ? Theme.fg : Theme.t1
    readonly property color dim: root.bare ? Theme.fgDim : Theme.t2
    readonly property color muted: root.bare ? Theme.fgMuted : Theme.t3
    readonly property color faint: root.bare ? Theme.alpha(Theme.fgMuted, 0.7) : Theme.t4

    readonly property color surface: root.bare ? Theme.alpha(Theme.bgAlt, 0.55) : Theme.s1
    readonly property color surfaceHover: root.bare ? Theme.bgAlt : Theme.s2
    readonly property color surfaceActive: root.bare ? Theme.alpha(Theme.accent, 0.2) : Theme.s3
    readonly property color onAccent: root.bare ? Theme.bg : Theme.fgOnAccent

    function r(n: int): int {
        return root.bare ? 0 : n;
    }
}
