pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var colors: ({})
    readonly property color accent: colors.accent ?? "#7fa8f5"
    readonly property color success: colors.success ?? "#4ec79b"
    readonly property color warning: colors.warning ?? "#e0a45e"
    readonly property color error: colors.error ?? "#ee7268"
    readonly property color info: colors.info ?? "#e294d2"
    readonly property string themeName: colors.theme ?? "built-in"
    readonly property bool light: colors.scheme === "light"

    readonly property color bg: colors.bg ?? "#11121a"
    readonly property color bgDim: colors.bgDim ?? "#0d0e14"
    readonly property color bgAlt: colors.bgAlt ?? "#1a1b26"
    readonly property color border: colors.border ?? "#2a2b3a"
    readonly property color fg: colors.fg ?? "#c8ccd8"
    readonly property color fgDim: colors.fgDim ?? "#8a8fa0"
    readonly property color fgMuted: colors.fgMuted ?? "#5a5f70"

    readonly property color ansiBlack: colors.black ?? "#1a1b26"
    readonly property color ansiRed: colors.red ?? "#ee7268"
    readonly property color ansiGreen: colors.green ?? "#4ec79b"
    readonly property color ansiYellow: colors.yellow ?? "#e0a45e"
    readonly property color ansiBlue: colors.blue ?? "#7fa8f5"
    readonly property color ansiMagenta: colors.magenta ?? "#e294d2"
    readonly property color ansiCyan: colors.cyan ?? "#5fc9d8"
    readonly property color ansiWhite: colors.white ?? "#c8ccd8"
    readonly property color ansiBrightBlack: colors.brightBlack ?? "#4a4f60"
    readonly property color ansiBrightRed: colors.brightRed ?? "#f58a80"
    readonly property color ansiBrightGreen: colors.brightGreen ?? "#6fdcb4"
    readonly property color ansiBrightYellow: colors.brightYellow ?? "#f0bc7a"
    readonly property color ansiBrightBlue: colors.brightBlue ?? "#9dbcff"
    readonly property color ansiBrightMagenta: colors.brightMagenta ?? "#f0aae4"
    readonly property color ansiBrightCyan: colors.brightCyan ?? "#7fdfec"
    readonly property color ansiBrightWhite: colors.brightWhite ?? "#ffffff"

    readonly property string themeMono: colors.mono || root.mono
    readonly property string themeIcons: /Nerd Font/.test(root.themeMono) ? root.themeMono.replace(/Nerd Font( Mono| Propo)?$/, "Nerd Font Propo") : root.themeMono
    readonly property int themeSize: parseInt(colors.size ?? "0") || 14
    readonly property int themeSizeSmall: parseInt(colors.sizeSmall ?? "0") || Math.round(root.themeSize * 0.9)

    FileView {
        path: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/theme-engine/notch-colors.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = JSON.parse(text());
            } catch (e) {
                root.colors = ({});
            }
        }
        onLoadFailed: root.colors = ({})
    }

    readonly property color notchSolid: "#050608"
    readonly property color notchGlass: "#0b0c10"
    readonly property color notchSplit: "#08090c"
    readonly property color s1: Qt.rgba(1, 1, 1, 0.045)
    readonly property color s2: Qt.rgba(1, 1, 1, 0.06)
    readonly property color s3: Qt.rgba(1, 1, 1, 0.09)
    readonly property color s4: Qt.rgba(1, 1, 1, 0.13)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.09)
    readonly property color track: Qt.rgba(1, 1, 1, 0.12)
    readonly property color scrim: Qt.rgba(4 / 255, 5 / 255, 7 / 255, 0.45)

    readonly property color t1: "#ffffff"
    readonly property color t2: Qt.rgba(1, 1, 1, 0.60)
    readonly property color t3: Qt.rgba(1, 1, 1, 0.42)
    readonly property color t4: Qt.rgba(1, 1, 1, 0.30)
    readonly property color fgOnAccent: "#0b0d11"

    readonly property string ui: "DM Sans"
    readonly property string mono: "JetBrains Mono"
    readonly property string icons: "Material Symbols Rounded"

    readonly property int rCollapsed: 18
    readonly property int rPeek: 20
    readonly property int rOsd: 22
    readonly property int rExpanded: 30
    readonly property int rCard: 15
    readonly property int rRow: 12
    readonly property int gutter: 16

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
