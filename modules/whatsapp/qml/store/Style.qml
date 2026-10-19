pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property string family: Theme.themeMono
    readonly property string monoFamily: Theme.themeMono

    readonly property int base: Theme.themeSizeSmall
    readonly property int title: Math.round(base * 1.2)
    readonly property int row: Math.round(base * 0.875)
    readonly property int body: Math.round(base * 0.8)
    readonly property int small: Math.round(base * 0.75)
    readonly property int tiny: Math.round(base * 0.7)

    readonly property color text: Theme.fg
    readonly property color dim: Theme.fgDim
    readonly property color muted: Theme.fgMuted
    readonly property color faint: Theme.alpha(Theme.fgMuted, 0.7)

    readonly property color surface: Theme.alpha(Theme.bgAlt, 0.55)
    readonly property color surfaceHover: Theme.bgAlt
    readonly property color surfaceActive: Theme.alpha(Theme.accent, 0.2)
    readonly property color onAccent: Theme.bg

    property bool soft: false
    readonly property color sidebar: Theme.alpha(Theme.bgDim, soft ? 1 : 0.80)

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/look`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.soft = text().trim() === "soft"
    }

    function r(n: int): int {
        return 0;
    }
}
