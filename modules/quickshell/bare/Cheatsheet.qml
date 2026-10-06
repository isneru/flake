import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    readonly property var groups: Bindings.forMode(true)
    readonly property int columns: 3

    readonly property var split: {
        const cols = [];
        const load = [];
        for (let c = 0; c < root.columns; c++) {
            cols.push([]);
            load.push(0);
        }
        for (const g of root.groups) {
            let c = 0;
            for (let k = 1; k < root.columns; k++)
                if (load[k] < load[c])
                    c = k;
            cols[c].push(g);
            load[c] += g.items.length + 2;
        }
        return cols;
    }

    readonly property string longest: root.groups
        .reduce((a, g) => a.concat(g.items.map(i => i[0])), [])
        .reduce((a, k) => k.length > a.length ? k : a, "")

    visible: Mode.cheatsheet
    color: Theme.alpha(Theme.bgDim, 0.55)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bare-keys"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) card.forceActiveFocus()

    TextMetrics {
        id: keyWidth
        font.family: Theme.themeMono
        font.pixelSize: Mode.barFont
        text: root.longest
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Mode.cheatsheet = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: body.implicitWidth + 40
        height: body.implicitHeight + 32
        radius: 0
        color: Theme.alpha(Theme.bgDim, 0.94)
        border.width: 1
        border.color: Theme.border
        focus: true

        Keys.onEscapePressed: Mode.cheatsheet = false

        Column {
            id: body
            anchors.centerIn: parent
            spacing: 14

            Text {
                text: "KEYBINDINGS"
                color: Theme.accent
                font.family: Theme.themeMono
                font.pixelSize: Mode.barFont
                renderType: Text.NativeRendering
            }

            Row {
                spacing: 40

                Repeater {
                    model: root.split

                    Column {
                        id: column
                        required property var modelData
                        spacing: 14

                        Repeater {
                            model: column.modelData

                            Column {
                                id: group
                                required property var modelData
                                spacing: 3

                                Text {
                                    text: group.modelData.title
                                    color: Theme.fgMuted
                                    font.family: Theme.themeMono
                                    font.pixelSize: Mode.barFont
                                    renderType: Text.NativeRendering
                                }

                                Repeater {
                                    model: group.modelData.items

                                    Row {
                                        id: line
                                        required property var modelData
                                        spacing: 16

                                        Text {
                                            width: keyWidth.advanceWidth
                                            text: line.modelData[0]
                                            color: Theme.accent
                                            font.family: Theme.themeMono
                                            font.pixelSize: Mode.barFont
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: line.modelData[1]
                                            color: Theme.fg
                                            font.family: Theme.themeMono
                                            font.pixelSize: Mode.barFont
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "[Esc] close    [SUPER+?] close    click anywhere to close"
                color: Theme.fgMuted
                font.family: Theme.themeMono
                font.pixelSize: Mode.barFont
                renderType: Text.NativeRendering
            }
        }
    }
}
