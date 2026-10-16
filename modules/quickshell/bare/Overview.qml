import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    property var rows: []
    property string sel: ""
    property string special: ""

    readonly property real left: rows.reduce((a, r) => Math.max(a, -r.left), 0)
    readonly property real view: rows.reduce((a, r) => Math.max(a, r.vw), 0)
    readonly property real right: rows.reduce((a, r) => Math.max(a, r.right - r.vw), 0)
    readonly property real tall: rows.reduce((a, r) => a + r.vh, 0)
    readonly property real s: {
        const w = (root.screen?.width ?? 1920) - 160 - labelWidth.advanceWidth - 16;
        const h = (root.screen?.height ?? 1080) - 200 - rows.length * 12;
        return Math.min(0.12, w / Math.max(1, left + view + right), h / Math.max(1, tall));
    }

    visible: Mode.overview && rows.length > 0
    color: Theme.alpha(Theme.bgDim, 0.55)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bare-overview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible)
        card.forceActiveFocus()

    Connections {
        target: Mode
        function onOverviewChanged() {
            if (Mode.overview)
                reader.running = true;
            else
                root.rows = [];
        }
    }

    Process {
        id: reader
        command: ["sh", "-c", "printf '[%s,%s]' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
        stdout: StdioCollector {
            onStreamFinished: if (Mode.overview)
                root.build(JSON.parse(text))
        }
    }

    function build(data) {
        const [clients, monitors] = data;
        const mons = {};
        const byWs = {};
        const add = (id, name, m) => byWs[id] || (byWs[id] = { id, name, m, wins: [] });
        let here = 0;
        for (const m of monitors) {
            mons[m.id] = m;
            add(m.activeWorkspace.id, m.activeWorkspace.name, m);
            if (m.focused) {
                here = m.specialWorkspace.id || m.activeWorkspace.id;
                root.special = m.specialWorkspace.name.replace("special:", "");
            }
        }
        let focused = "";
        for (const c of clients) {
            const m = mons[c.monitor];
            if (!m || !c.mapped || c.hidden)
                continue;
            add(c.workspace.id, c.workspace.name, m).wins.push({
                addr: c.address,
                label: Menu.short(c.class) + (c.grouped.length > 1 ? ` +${c.grouped.length - 1}` : ""),
                x: c.at[0] - m.x,
                y: c.at[1] - m.y,
                w: c.size[0],
                h: c.size[1],
                floating: c.floating,
                focused: c.focusHistoryID === 0
            });
            if (c.focusHistoryID === 0)
                focused = c.address;
        }
        const rows = Object.values(byWs).map(r => {
            const vw = r.m.width / r.m.scale;
            const vh = r.m.height / r.m.scale;
            r.wins.sort((a, b) => a.x - b.x || a.y - b.y);
            return {
                label: r.id > 0 ? (r.id === here ? `[${r.name}]` : ` ${r.name} `) : r.name.replace("special:", ""),
                current: r.id === here,
                vw,
                vh,
                left: r.wins.reduce((a, w) => Math.min(a, w.x), 0),
                right: r.wins.reduce((a, w) => Math.max(a, w.x + w.w), vw),
                wins: r.wins,
                id: r.id
            };
        });
        rows.sort((a, b) => (a.id < 0) - (b.id < 0) || Math.abs(a.id) - Math.abs(b.id));
        const cur = rows.find(r => r.current);
        root.sel = focused || (cur?.wins[0] ?? rows.find(r => r.wins.length)?.wins[0])?.addr || "";
        root.rows = rows;
    }

    function move(dx, dy) {
        let r = rows.findIndex(row => row.wins.some(w => w.addr === sel));
        if (r < 0)
            return;
        const wins = rows[r].wins;
        const i = wins.findIndex(w => w.addr === sel);
        const w = wins[i];
        if (dx) {
            if (wins[i + dx])
                sel = wins[i + dx].addr;
            return;
        }
        const column = wins.filter(o => !o.floating && !w.floating && o.x === w.x);
        const k = column.findIndex(o => o.addr === sel);
        if (column[k + dy]) {
            sel = column[k + dy].addr;
            return;
        }
        const cx = w.x + w.w / 2;
        for (r += dy; r >= 0 && r < rows.length; r += dy) {
            let best = null;
            let d = Infinity;
            for (const o of rows[r].wins) {
                const e = Math.abs(o.x + o.w / 2 - cx) * 10000 + (dy > 0 ? o.y : -o.y);
                if (e < d) {
                    d = e;
                    best = o;
                }
            }
            if (best) {
                sel = best.addr;
                return;
            }
        }
    }

    function pick(addr) {
        const row = rows.find(r => r.wins.some(w => w.addr === addr));
        Mode.overview = false;
        if (!row)
            return;
        if (row.id > 0 && root.special)
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${root.special}")`);
        Hyprland.dispatch(`hl.dsp.focus{ window = "address:${addr}" }`);
    }

    TextMetrics {
        id: labelWidth
        font.family: Theme.themeMono
        font.pixelSize: Mode.barFont
        text: "[10]"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Mode.overview = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: body.implicitWidth + 40
        height: body.implicitHeight + 32
        radius: Mode.radius
        color: Mode.alpha(Theme.bgDim, 0.94)
        border.width: 1
        border.color: Theme.border
        focus: true

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape)
                Mode.overview = false;
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                root.pick(root.sel);
            else if (k === Qt.Key_Left || k === Qt.Key_H)
                root.move(-1, 0);
            else if (k === Qt.Key_Right || k === Qt.Key_L)
                root.move(1, 0);
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                root.move(0, -1);
            else if (k === Qt.Key_Down || k === Qt.Key_J)
                root.move(0, 1);
            else
                return;
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: body
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "OVERVIEW"
                color: Theme.accent
                font.family: Theme.themeMono
                font.pixelSize: Mode.barFont
                renderType: Text.NativeRendering
            }

            Repeater {
                model: root.rows

                Row {
                    id: line
                    required property var modelData
                    spacing: 16

                    Text {
                        width: labelWidth.advanceWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.label
                        color: line.modelData.current ? Theme.accent : Theme.fgMuted
                        font.family: Theme.themeMono
                        font.pixelSize: Mode.barFont
                        renderType: Text.NativeRendering
                    }

                    Item {
                        width: (root.left + root.view + root.right) * root.s
                        height: line.modelData.vh * root.s

                        Repeater {
                            model: line.modelData.wins

                            Rectangle {
                                id: tile
                                required property var modelData
                                readonly property bool chosen: tile.modelData.addr === root.sel
                                readonly property real mid: tile.modelData.x + tile.modelData.w / 2
                                x: (root.left + tile.modelData.x) * root.s
                                y: tile.modelData.y * root.s
                                z: tile.modelData.floating ? 2 : 1
                                width: tile.modelData.w * root.s
                                height: tile.modelData.h * root.s
                                opacity: tile.chosen || (tile.mid > 0 && tile.mid < line.modelData.vw) ? 1 : 0.45
                                color: tile.modelData.focused ? Theme.bgAlt : Theme.bg
                                border.width: 1
                                border.color: tile.chosen ? Theme.accent : Theme.border

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    text: tile.modelData.label
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    color: tile.chosen ? Theme.accent : tile.modelData.focused ? Theme.fg : Theme.fgDim
                                    font.family: Theme.themeMono
                                    font.pixelSize: Mode.barFont
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.pick(tile.modelData.addr)
                                }
                            }
                        }

                        Rectangle {
                            x: root.left * root.s
                            z: 3
                            width: line.modelData.vw * root.s
                            height: parent.height
                            color: "transparent"
                            border.width: 1
                            border.color: line.modelData.current ? Theme.accent : Theme.fgMuted
                        }
                    }
                }
            }

            Text {
                text: "[←↑↓→ / HJKL] move    [Enter] focus    [Esc] close"
                color: Theme.fgMuted
                font.family: Theme.themeMono
                font.pixelSize: Mode.barFont
                renderType: Text.NativeRendering
            }
        }
    }
}
