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

    readonly property string themeMono: colors.mono || "monospace"
    readonly property string themeIcons: /Nerd Font/.test(root.themeMono) ? root.themeMono.replace(/Nerd Font( Mono| Propo)?$/, "Nerd Font Propo") : root.themeMono
    readonly property int themeSize: parseInt(colors.size ?? "0") || 14
    readonly property int themeSizeSmall: parseInt(colors.sizeSmall ?? "0") || Math.round(root.themeSize * 0.9)

    FileView {
        path: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/theme-engine/bare-colors.json`
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

    readonly property string icons: "Material Symbols Rounded"

    readonly property int rRow: 12

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
