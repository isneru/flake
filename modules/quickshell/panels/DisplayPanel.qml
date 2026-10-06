import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var mons: Hyprland.monitors.values
    property int selected: 0
    readonly property var mon: mons[Math.min(selected, mons.length - 1)] ?? null
    readonly property var raw: mon?.lastIpcObject ?? null

    readonly property real maxW: {
        let w = 1;
        for (const m of mons)
            w = Math.max(w, m.lastIpcObject?.width ?? 1);
        return w;
    }

    readonly property var turns: ["0°", "90°", "180°", "270°"]
    readonly property var scales: ["1", "1.25", "1.5", "1.75", "2"]

    readonly property var rule: mon ? Display.ruleFor(mon.name) : ({})
    readonly property bool disabled: (rule.disabled ?? "") === "1"

    readonly property var modes: (raw?.availableModes ?? []).map(m => m.replace("Hz", ""))
    readonly property string modeLabel: (raw?.width ?? 0) + "x" + (raw?.height ?? 0)
        + " - " + Math.round(raw?.refreshRate ?? 0) + " Hz"
    readonly property string vrrLabel: (rule.vrr ?? "0") === "0" ? "off" : ((rule.vrr === "2") ? "fullscreen" : "on")
    readonly property string mirrorLabel: (rule.mirror ?? "") === "" ? "Mirror" : "Mirroring " + rule.mirror

    function nextIn(list, current) {
        const i = list.indexOf(current);
        return list[(i + 1) % list.length];
    }

    function cycle(key) {
        if (!mon)
            return;
        if (key === "mode") {
            if (modes.length < 2)
                return;
            const here = raw.width + "x" + raw.height + "@" + Math.round(raw.refreshRate ?? 0);
            const now = modes.find(m => m.startsWith(here)) ?? modes[0];
            Display.set(mon.name, "mode", root.nextIn(modes, now));
        } else if (key === "scale") {
            Display.set(mon.name, "scale", root.nextIn(scales, String(parseFloat((raw?.scale ?? 1).toFixed(2)))));
        } else if (key === "vrr") {
            Display.set(mon.name, "vrr", root.nextIn(["0", "1", "2"], rule.vrr ?? "0"));
        } else if (key === "transform") {
            Display.set(mon.name, "transform", root.nextIn(["0", "1", "2", "3"], String(raw?.transform ?? 0)));
        }
    }

    function run(act) {
        if (!mon)
            return;
        if (act === "reset")
            Display.reset(mon.name);
        else if (act === "disable")
            Display.set(mon.name, "disabled", root.disabled ? "" : "1");
        else if (act === "mirror") {
            const others = mons.filter(m => m.name !== mon.name).map(m => m.name);
            if (!others.length)
                return;
            const now = rule.mirror ?? "";
            const i = others.indexOf(now);
            Display.set(mon.name, "mirror", i + 1 >= others.length ? "" : others[i + 1]);
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 190
        Layout.fillHeight: false

        Row {
            anchors.centerIn: parent
            spacing: 14

            Repeater {
                model: root.mons

                delegate: Rectangle {
                    id: out
                    required property var modelData
                    required property int index
                    readonly property var geo: modelData.lastIpcObject
                    readonly property bool active: root.selected === index

                    width: 300 * (geo?.width ?? 1920) / root.maxW
                    height: width * (geo?.height ?? 1080) / (geo?.width ?? 1920)
                    radius: 10
                    color: Theme.s1
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : Theme.hairline
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                    TapHandler { onTapped: root.selected = out.index }

                    Rectangle {
                        visible: out.geo?.focused ?? false
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: primaryLabel.implicitWidth + 14
                        height: 18
                        radius: 9
                        color: Theme.accent
                        Text {
                            id: primaryLabel
                            anchors.centerIn: parent
                            text: "PRIMARY"
                            font.family: Theme.ui
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                            color: Theme.fgOnAccent
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: out.modelData.name
                            font.family: Theme.mono
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.t1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (out.geo?.width ?? 0) + "x" + (out.geo?.height ?? 0)
                                + " - " + Math.round(out.geo?.refreshRate ?? 0) + " Hz"
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.t3
                        }
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        columns: 4
        columnSpacing: 10

        Repeater {
            model: [
                { key: "mode", label: "Mode", value: root.modeLabel, on: false },
                { key: "scale", label: "Scale", value: (root.raw?.scale ?? 1).toFixed(2), on: false },
                { key: "vrr", label: "VRR", value: root.vrrLabel, on: (root.raw?.vrr ?? false) },
                { key: "transform", label: "Rotation", value: root.turns[root.raw?.transform ?? 0] ?? "0°", on: (root.raw?.transform ?? 0) !== 0 }
            ]
            delegate: Rectangle {
                id: opt
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 14
                color: modelData.on ? Theme.accent : (optHover.hovered ? Theme.s3 : Theme.s2)
                Behavior on color { ColorAnimation { duration: 160 } }
                HoverHandler { id: optHover }
                TapHandler { onTapped: root.cycle(opt.modelData.key) }

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: opt.modelData.label
                        font.family: Theme.ui
                        font.pixelSize: 11
                        color: opt.modelData.on ? Qt.rgba(0, 0, 0, 0.55) : Theme.t3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: opt.modelData.value
                        font.family: Theme.mono
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: opt.modelData.on ? Theme.fgOnAccent : Theme.t1
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 38
        spacing: 10

        Repeater {
            model: [
                { act: "disable", icon: "desktop_access_disabled", label: root.disabled ? "Enable" : "Disable", danger: !root.disabled },
                { act: "mirror", icon: "screen_share", label: root.mirrorLabel, danger: false },
                { act: "reset", icon: "restart_alt", label: "Reset", danger: false }
            ]
            delegate: Rectangle {
                id: btn
                required property var modelData
                readonly property bool usable: btn.modelData.act !== "mirror" || root.mons.length > 1

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                opacity: usable ? 1 : 0.4
                color: btnHover.hovered && usable ? (btn.modelData.danger ? Theme.error : Theme.s3) : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }
                HoverHandler { id: btnHover }
                TapHandler {
                    enabled: btn.usable
                    onTapped: root.run(btn.modelData.act)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                        text: btn.modelData.icon
                        color: Theme.t2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btn.modelData.label
                        font.family: Theme.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.t1
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.fillHeight: false
        radius: 13
        color: Qt.rgba(1, 1, 1, 0.035)

        Text {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            verticalAlignment: Text.AlignVCenter
            text: root.raw
                ? "monitor = " + root.mon.name + "," + root.raw.width + "x" + root.raw.height
                    + "@" + (root.raw.refreshRate ?? 0).toFixed(2)
                    + "," + root.raw.x + "x" + root.raw.y + "," + (root.raw.scale ?? 1).toFixed(2)
                : ""
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.alpha(Theme.t1, 0.45)
            elide: Text.ElideRight
        }
    }
}
