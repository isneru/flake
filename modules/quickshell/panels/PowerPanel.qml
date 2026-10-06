import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var bat: UPower.devices.values.find(d => d.isLaptopBattery) ?? UPower.displayDevice
    readonly property int pct: Math.round((bat?.percentage ?? 0) * 100)
    readonly property bool charging: bat?.state === UPowerDeviceState.Charging

    property string armedKey: ""
    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armedKey = ""
    }

    property string health: ""
    readonly property string sysfs: bat?.nativePath ? "/sys/class/power_supply/" + bat.nativePath : ""

    FileView {
        id: full
        path: root.sysfs ? root.sysfs + "/energy_full" : ""
        onLoaded: root.recomputeHealth()
    }
    FileView {
        id: design
        path: root.sysfs ? root.sysfs + "/energy_full_design" : ""
        onLoaded: root.recomputeHealth()
    }
    FileView {
        id: cycles
        path: root.sysfs ? root.sysfs + "/cycle_count" : ""
        onLoaded: root.recomputeHealth()
    }

    function recomputeHealth() {
        const f = parseInt(full.text());
        const d = parseInt(design.text());
        const c = parseInt(cycles.text());
        const bits = [];
        if (c > 0)
            bits.push("cycles " + c);
        if (f > 0 && d > 0)
            bits.push("health " + Math.round(100 * f / d) + "%");
        health = bits.join(" - ");
    }

    function hours(s) {
        if (!(s > 0))
            return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property string status: {
        if (!bat)
            return "no battery";
        switch (bat.state) {
        case UPowerDeviceState.Charging:
            return "Charging" + (hours(bat.timeToFull) ? " - " + hours(bat.timeToFull) + " to full" : "");
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.Discharging:
            return "On battery" + (hours(bat.timeToEmpty) ? " - " + hours(bat.timeToEmpty) + " left" : "");
        default:
            return UPowerDeviceState.toString(bat.state);
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        Layout.fillHeight: false
        radius: 16
        color: Theme.s1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.pct + "%"
                        font.family: Theme.mono
                        font.pixelSize: 30
                        font.weight: Font.Light
                        color: Theme.t1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.status
                        font.family: Theme.ui
                        font.pixelSize: 12
                        color: root.charging ? Theme.success : Theme.accent
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 4

                    Repeater {
                        model: [
                            (root.bat?.nativePath || "BAT0") + " - " + (root.bat?.energyCapacity ?? 0).toFixed(1) + " Wh",
                            Math.abs(root.bat?.changeRate ?? 0).toFixed(1) + " W " + (root.charging ? "charge" : "draw"),
                            root.health
                        ]
                        delegate: Text {
                            required property string modelData
                            visible: modelData !== ""
                            Layout.alignment: Qt.AlignRight
                            horizontalAlignment: Text.AlignRight
                            text: modelData
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.t3
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                radius: 4
                color: Theme.track
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, root.pct)) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.charging ? Theme.success : (root.pct <= 15 ? Theme.warning : Theme.accent)
                    Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.Bezier; easing.bezierCurve: [0.3, 0.9, 0.3, 1, 1, 1] } }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 92
        spacing: 11

        Repeater {
            model: [
                { p: PowerProfile.PowerSaver, icon: "eco", label: "Power saver", sub: "longest runtime" },
                { p: PowerProfile.Balanced, icon: "balance", label: "Balanced", sub: "default" },
                { p: PowerProfile.Performance, icon: "rocket_launch", label: "Performance", sub: "highest clocks" }
            ]

            delegate: Rectangle {
                id: prof
                required property var modelData
                readonly property bool on: PowerProfiles.profile === modelData.p
                readonly property bool avail: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 15
                color: on ? Theme.accent : Theme.s2
                opacity: avail ? 1 : 0.4
                Behavior on color { ColorAnimation { duration: 220 } }
                TapHandler {
                    enabled: prof.avail
                    onTapped: PowerProfiles.profile = prof.modelData.p
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 22
                        filled: true
                        text: prof.modelData.icon
                        color: prof.on ? Theme.fgOnAccent : Theme.t2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: prof.modelData.label
                        font.family: Theme.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: prof.on ? Theme.fgOnAccent : Theme.t1
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: prof.modelData.sub
                        font.family: Theme.ui
                        font.pixelSize: 10
                        color: prof.on ? Qt.rgba(0, 0, 0, 0.5) : Theme.t3
                    }
                }
            }
        }
    }

    Text {
        Layout.topMargin: 4
        text: "SESSION"
        font.family: Theme.ui
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.55
        color: Theme.t3
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 76
        spacing: 11

        Repeater {
            model: [
                { key: "suspend", icon: "bedtime", label: "Suspend", cmd: ["systemctl", "suspend"], confirm: false },
                { key: "logout", icon: "logout", label: "Log out", cmd: ["uwsm", "stop"], confirm: true },
                { key: "reboot", icon: "restart_alt", label: "Reboot", cmd: ["systemctl", "reboot"], confirm: true },
                { key: "windows", icon: "desktop_windows", label: "Windows", cmd: ["systemctl", "reboot", "--boot-loader-entry=auto-windows"], confirm: true },
                { key: "uefi", icon: "developer_board", label: "UEFI", cmd: ["systemctl", "reboot", "--firmware-setup"], confirm: true },
                { key: "shutdown", icon: "power_settings_new", label: "Shut down", cmd: ["systemctl", "poweroff"], confirm: true }
            ]

            delegate: Rectangle {
                id: act
                required property var modelData
                readonly property bool armed: root.armedKey === modelData.key

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 15
                color: armed ? Theme.error : (actHover.hovered ? Theme.s3 : Theme.s2)
                Behavior on color { ColorAnimation { duration: 180 } }
                HoverHandler { id: actHover }
                TapHandler {
                    onTapped: {
                        if (!act.modelData.confirm || act.armed) {
                            root.armedKey = "";
                            Quickshell.execDetached(act.modelData.cmd);
                        } else {
                            root.armedKey = act.modelData.key;
                            disarm.restart();
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 22
                        filled: true
                        text: act.modelData.icon
                        color: act.armed ? Theme.fgOnAccent : Theme.t2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: act.armed ? "Confirm?" : act.modelData.label
                        font.family: Theme.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: act.armed ? Theme.fgOnAccent : Theme.t1
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }

    Rectangle {
        visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        Layout.fillHeight: false
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.035)
        Text {
            anchors.fill: parent
            anchors.leftMargin: 14
            verticalAlignment: Text.AlignVCenter
            text: "performance degraded - "
                + PerformanceDegradationReason.toString(PowerProfiles.degradationReason)
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.warning
            elide: Text.ElideRight
        }
    }
}
