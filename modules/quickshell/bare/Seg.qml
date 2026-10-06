import QtQuick
import "root:/singletons"

Rectangle {
    id: root

    property string text: ""
    property color fg: Theme.fg
    property bool interactive: true
    property int buttons: Qt.LeftButton
    property int minChars: 0
    property bool tight: false
    property bool richText: false
    property color fill: "transparent"
    property bool packIcons: false
    signal clicked(int button)

    readonly property int pad: tight ? Math.round(cell.advanceWidth / 3) : 8
    readonly property var iconRun: /(?:[\uE000-\uF8FF]|[\uDB80-\uDBBF][\uDC00-\uDFFF])+/g
    readonly property bool hasIcon: !richText && /[\uE000-\uF8FF\uDB80-\uDBBF]/.test(text)
    readonly property real trim: packIcons ? Mode.barIcon / 4 - Mode.barFont / 20 : 0
    readonly property string iconText: hasIcon ? text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;")
        .replace(/[^;\s\uE000-\uF8FF\uDC00-\uDFFF](?=[\uE000-\uF8FF\uDB80-\uDBBF])/g, c => spaced(c, -trim))
        .replace(iconRun, m => `<span style="font-family:'${Theme.themeIcons}';font-size:${Mode.barIcon}px;vertical-align:middle">${Array.from(m).map((c, i, all) => spaced(c, (i < all.length - 1 ? -2 : -1) * trim)).join("")}</span>`) : ""
    readonly property bool filled: fill.a > 0
    readonly property int inset: filled ? Math.round(cell.advanceWidth / 2) : 0

    implicitWidth: Math.max(label.implicitWidth, Math.ceil(cell.advanceWidth * root.minChars)) + (pad + inset) * 2
    implicitHeight: parent ? parent.height : 24
    radius: 0
    color: area.containsMouse && root.interactive && !root.filled ? Theme.bgAlt : "transparent"

    function spaced(c: string, px: real): string {
        return px ? `<span style="letter-spacing:${px}px">${c}</span>` : c;
    }

    TextMetrics {
        id: cell
        font: label.font
        text: "0"
    }

    Rectangle {
        visible: root.filled
        x: root.pad
        width: root.width - root.pad * 2
        height: root.height
        color: area.containsMouse && root.interactive ? Qt.lighter(root.fill, 1.15) : root.fill
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round((root.width - width) / 2)
        text: root.hasIcon ? root.iconText : root.text
        color: root.fg
        font.family: Theme.themeMono
        font.pixelSize: Mode.barFont
        textFormat: root.hasIcon ? Text.RichText : root.richText ? Text.StyledText : Text.PlainText
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        acceptedButtons: root.buttons
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => root.clicked(mouse.button)
    }
}
