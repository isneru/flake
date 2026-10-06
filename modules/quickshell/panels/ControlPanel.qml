import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    component MiniTile: Rectangle {
        id: mini
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color activeColor: Theme.accent
        property bool scrollable: false
        property bool readOnly: false
        signal clicked
        signal scrolled(int steps)

        radius: 15
        color: on ? activeColor : Theme.s2
        Behavior on color { ColorAnimation { duration: 240 } }

        readonly property color fg: on ? Theme.fgOnAccent : Qt.rgba(1, 1, 1, 0.92)

        Column {
            anchors.centerIn: parent
            spacing: 7
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 21
                filled: true
                text: mini.icon
                color: mini.fg
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: mini.width - 12
                horizontalAlignment: Text.AlignHCenter
                text: mini.label
                font.family: Theme.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                color: mini.fg
                elide: Text.ElideRight
            }
            Text {
                visible: text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: mini.width - 12
                horizontalAlignment: Text.AlignHCenter
                text: mini.sub
                font.family: Theme.ui
                font.pixelSize: 10
                color: mini.on ? Qt.rgba(0, 0, 0, 0.5) : Theme.t3
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: mini.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: if (!mini.readOnly) mini.clicked()
            onEntered: if (!mini.readOnly) mini.scale = 1.01
            onExited: mini.scale = 1
            onWheel: wheel => {
                if (!mini.scrollable) {
                    wheel.accepted = false;
                    return;
                }
                if (wheel.angleDelta.y !== 0)
                    mini.scrolled(wheel.angleDelta.y > 0 ? 1 : -1);
            }
        }
        Behavior on scale { NumberAnimation { duration: 180 } }
    }

    readonly property var tiles: [
        { key: "wifi", icon: NotchState.wired ? "lan" : "wifi", label: "Wi-Fi", c: Theme.accent },
        { key: "bt", icon: "bluetooth", label: "Bluetooth", c: Theme.accent },
        { key: "dnd", icon: "do_not_disturb_on", label: "Do not disturb", c: Theme.warning },
        { key: "night", icon: "nightlight", label: "Night light", c: Theme.warning, wheel: true },
        { key: "vpn", icon: "vpn_key", label: "VPN", c: Theme.success },
        { key: "firewall", icon: "security", label: "Firewall", c: Theme.success, readonly: true },
        { key: "idleInhibit", icon: "coffee", label: "Idle inhibit", c: Theme.accent }
    ]

    function subFor(key) {
        const on = NotchState.toggles[key];
        switch (key) {
        case "wifi":

            if (NotchState.wired)
                return NotchState.networkName;
            return on ? (NotchState.ssid || "not connected") : "off";
        case "bt":
            return on ? NotchState.btConnected + " connected" : "off";
        case "night":
            return on ? NightLight.temperature + " K" : "off";
        case "vpn":
            return on ? "connected" : "disconnected";
        case "firewall":
            return on ? "active" : "inactive";
        case "idleInhibit":
            return on ? "screen stays on" : "off";
        default:
            return on ? "on" : "off";
        }
    }

    ColumnLayout {
        visible: Config.ccLayout === "grid"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 120
            columns: 2
            columnSpacing: 10
            Repeater {
                model: Config.ccLayout === "grid" ? root.tiles.slice(0, 2) : []
                delegate: Tile {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: modelData.icon
                    label: modelData.label
                    sub: root.subFor(modelData.key)
                    on: NotchState.toggles[modelData.key]
                    activeColor: modelData.c
                    onClicked: NotchState.toggle(modelData.key)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 5
            columnSpacing: 10
            Repeater {
                model: Config.ccLayout === "grid" ? root.tiles.slice(2) : []
                delegate: MiniTile {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: modelData.icon
                    label: modelData.label
                    sub: (modelData.wheel === true || modelData.readonly === true) ? root.subFor(modelData.key) : ""
                    on: NotchState.toggles[modelData.key]
                    activeColor: modelData.c
                    readOnly: modelData.readonly === true
                    scrollable: modelData.wheel === true && NotchState.toggles[modelData.key]
                    onClicked: NotchState.toggle(modelData.key)
                    onScrolled: steps => NightLight.step(steps)
                }
            }
        }
    }

    GridLayout {
        visible: Config.ccLayout === "rows"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.maximumHeight: 320
        columns: 2
        rowSpacing: 8
        columnSpacing: 14
        Repeater {
            model: Config.ccLayout === "rows" ? root.tiles : []
            delegate: Rectangle {
                id: rowTile
                required property var modelData
                readonly property bool isOn: NotchState.toggles[modelData.key]
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                readonly property bool readOnly: modelData.readonly === true
                color: (hov.hovered && !readOnly) ? Theme.s3 : Theme.s1
                HoverHandler { id: hov; enabled: !rowTile.readOnly }
                TapHandler { enabled: !rowTile.readOnly; onTapped: NotchState.toggle(modelData.key) }
                WheelHandler {
                    enabled: rowTile.modelData.wheel === true && rowTile.isOn
                    onWheel: event => NightLight.step(event.angleDelta.y > 0 ? 1 : -1)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 11
                    Icon {
                        size: 19
                        filled: true
                        text: modelData.icon
                        color: rowTile.isOn ? modelData.c : Theme.alpha(Theme.t1, 0.4)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: modelData.label
                            font.family: Theme.ui
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.92)
                        }
                        Text {
                            text: root.subFor(modelData.key)
                            font.family: Theme.ui
                            font.pixelSize: 10
                            color: Theme.alpha(Theme.t1, 0.4)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Toggle {
                        visible: !rowTile.readOnly
                        checked: rowTile.isOn
                        activeColor: modelData.c
                        onToggled: NotchState.toggle(modelData.key)
                    }
                    Text {
                        visible: rowTile.readOnly
                        text: root.subFor(modelData.key)
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: rowTile.isOn ? modelData.c : Theme.alpha(Theme.t1, 0.4)
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 64
        columns: 2
        columnSpacing: 14
        Repeater {
            model: [
                { icon: NotchState.wired ? "lan" : "wifi", label: NotchState.wired ? "Network" : "Wi-Fi network", value: NotchState.networkName || "not connected", target: "wifi" },
                { icon: "bluetooth", label: "Bluetooth devices", value: NotchState.btConnected + " connected", target: "bt" }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 11
                color: h2.hovered ? Theme.s3 : Qt.rgba(1, 1, 1, 0.04)
                Behavior on color { ColorAnimation { duration: 160 } }
                HoverHandler { id: h2 }
                TapHandler { onTapped: NotchState.open(modelData.target) }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Icon { size: 18; text: modelData.icon; color: Theme.t2 }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        font.family: Theme.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Qt.rgba(1, 1, 1, 0.9)
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.maximumWidth: parent.width * 0.45
                        text: modelData.value
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.alpha(Theme.t1, 0.4)
                        elide: Text.ElideRight
                    }
                    Icon { size: 17; text: "chevron_right"; color: Theme.t4 }
                }
            }
        }
    }
}
