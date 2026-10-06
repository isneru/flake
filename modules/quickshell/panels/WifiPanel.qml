import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var nets: {
        const l = wifi ? wifi.networks.values.slice() : [];

        l.sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
        return l;
    }
    readonly property var active: nets.find(n => n.connected) ?? null

    property var pending: null
    property var armed: null
    property string failure: ""

    onWifiChanged: if (wifi) wifi.scannerEnabled = true

    Component.onCompleted: if (wifi) wifi.scannerEnabled = true

    Component.onDestruction: if (wifi) wifi.scannerEnabled = false

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = null
    }

    Timer {
        id: clearFailure
        interval: 6000
        onTriggered: root.failure = ""
    }

    readonly property var failText: ({
        [ConnectionFailReason.NoSecrets]: "wrong password",
        [ConnectionFailReason.WifiAuthTimeout]: "authentication timed out",
        [ConnectionFailReason.WifiNetworkLost]: "network went out of range",
        [ConnectionFailReason.WifiClientDisconnected]: "disconnected",
        [ConnectionFailReason.WifiClientFailed]: "could not associate"
    })

    Instantiator {
        model: root.nets
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                root.failure = modelData.name + " - " + (root.failText[reason] ?? ConnectionFailReason.toString(reason));
                if (root.pending === modelData)
                    root.pending = null;
                clearFailure.restart();
            }
        }
    }

    function secure(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }

    function rescan() {
        if (wifi) {
            wifi.scannerEnabled = false;
            wifi.scannerEnabled = true;
        }
    }

    Tabs {
        Layout.fillWidth: true
        Layout.fillHeight: false
        options: [{ key: "wifi", label: "Wi-Fi" }, { key: "net", label: "Stats" }]
        current: "wifi"
        onPicked: k => NotchState.open(k)
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 56
        radius: Theme.rCard
        color: Theme.s1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 13

            Icon {
                size: 21
                filled: true
                text: (Networking.wifiEnabled && Networking.wifiHardwareEnabled) ? "wifi" : "wifi_off"
                color: (Networking.wifiEnabled && Networking.wifiHardwareEnabled) ? Theme.accent : Theme.t3
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: !Networking.wifiHardwareEnabled ? "Wi-Fi blocked by hardware switch"
                        : (!Networking.wifiEnabled ? "Wi-Fi off" : (root.active?.name ?? "Not connected"))
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.t1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    readonly property var a: root.active
                    text: {
                        if (!Networking.wifiEnabled || !a)
                            return root.wifi?.name ?? "";
                        const bits = [];
                        if (root.wifi?.address)
                            bits.push(root.wifi.address);
                        bits.push(WifiSecurityType.toString(a.security));
                        bits.push(Math.round(a.signalStrength * 100) + "%");
                        return bits.join(" - ");
                    }
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.t3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                visible: Networking.wifiEnabled && Networking.wifiHardwareEnabled
                color: scanHover.hovered ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }
                HoverHandler { id: scanHover }
                TapHandler { onTapped: root.rescan() }
                Icon {
                    anchors.centerIn: parent
                    size: 16
                    text: "refresh"
                    color: Theme.t2
                    RotationAnimation on rotation {
                        running: root.wifi?.scannerEnabled ?? false
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1600
                    }
                }
            }
            Toggle {
                enabled: Networking.wifiHardwareEnabled
                opacity: Networking.wifiHardwareEnabled ? 1 : 0.4
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: root.failure ? 34 : 0
        visible: height > 0
        clip: true
        radius: 11
        color: Theme.alpha(Theme.error, 0.16)
        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 9
            Icon { size: 16; text: "error"; color: Theme.error }
            Text {
                Layout.fillWidth: true
                text: root.failure
                font.family: Theme.ui
                font.pixelSize: 11
                color: Theme.t1
                elide: Text.ElideRight
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Networking.wifiEnabled
        clip: true
        spacing: 8
        model: root.nets
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: net
            required property var modelData
            width: ListView.view.width
            height: 44
            radius: 12
            color: netHover.hovered ? Theme.s3 : Theme.s1
            Behavior on color { ColorAnimation { duration: 160 } }
            HoverHandler { id: netHover }
            TapHandler {
                onTapped: {
                    root.armed = null;
                    if (net.modelData.connected || net.modelData.known)
                        return;
                    if (!root.secure(net.modelData))
                        net.modelData.connect();
                    else
                        root.pending = net.modelData;
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 12

                Row {
                    Layout.preferredWidth: 18
                    spacing: 2
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 3
                            height: 5 + index * 3
                            y: 14 - height
                            radius: 1

                            color: (net.modelData.signalStrength * 4) > index
                                ? Qt.rgba(1, 1, 1, 0.85)
                                : Qt.rgba(1, 1, 1, 0.2)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: net.modelData.name
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.t1
                    elide: Text.ElideRight
                }
                Text {
                    text: Math.round(net.modelData.signalStrength * 100) + "%"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.t3
                }
                Icon {
                    size: 15
                    text: "lock"
                    color: Theme.t3
                    visible: root.secure(net.modelData)
                }
                Text {
                    visible: text !== ""
                    text: {
                        if (net.modelData.stateChanging)
                            return "connecting…";
                        if (root.pending === net.modelData)
                            return "password…";
                        if (net.modelData.connected)
                            return "connected";
                        return "";
                    }
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.accent
                }
                Repeater {
                    model: {
                        if (net.modelData.stateChanging || root.pending === net.modelData)
                            return [];
                        const acts = [];
                        if (net.modelData.connected)
                            acts.push({ act: "disconnect", icon: "link_off", danger: false });
                        if (net.modelData.known)
                            acts.push({ act: "forget", icon: "delete", danger: true });
                        return acts;
                    }
                    delegate: Rectangle {
                        id: act
                        required property var modelData
                        readonly property bool isArmed: root.armed === net.modelData.name + ":" + modelData.act

                        Layout.preferredWidth: isArmed ? confirm.implicitWidth + 20 : 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: isArmed ? Theme.error : (actHover.hovered ? Theme.s3 : Theme.s2)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        HoverHandler { id: actHover }
                        TapHandler {
                            onTapped: {
                                const key = net.modelData.name + ":" + act.modelData.act;
                                if (act.modelData.danger && root.armed !== key) {
                                    root.armed = key;
                                    disarm.restart();
                                    return;
                                }
                                root.armed = null;
                                if (act.modelData.act === "forget")
                                    net.modelData.forget();
                                else
                                    net.modelData.disconnect();
                            }
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !act.isArmed
                            size: 15
                            text: act.modelData.icon
                            color: Theme.t2
                        }
                        Text {
                            id: confirm
                            anchors.centerIn: parent
                            visible: act.isArmed
                            text: "Forget?"
                            font.family: Theme.ui
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.fgOnAccent
                        }
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !Networking.wifiEnabled

        Column {
            anchors.centerIn: parent
            spacing: 8
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 30
                text: "wifi_off"
                color: Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wi-Fi is off"
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t3
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: root.pending ? 50 : 0
        visible: height > 0
        clip: true
        radius: 13
        color: Theme.s2
        Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 12

            Icon { size: 19; text: "password"; color: Theme.t2 }
            TextInput {
                id: psk
                Layout.fillWidth: true
                echoMode: TextInput.Password
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t1
                selectionColor: Theme.accent
                clip: true
                onAccepted: join.go()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: psk.text === ""
                    text: "Password for " + (root.pending?.name ?? "")
                    font: psk.font
                    color: Theme.t4
                }
            }
            Rectangle {
                id: join
                function go() {
                    if (root.pending && psk.text) {
                        root.pending.connectWithPsk(psk.text);
                        root.pending = null;
                        psk.text = "";
                    }
                }
                Layout.preferredWidth: 62
                Layout.preferredHeight: 30
                radius: 15
                color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: "Join"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.fgOnAccent
                }
                TapHandler { onTapped: join.go() }
            }
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 30
                radius: 15
                color: Theme.s3
                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.t2
                }
                TapHandler {
                    onTapped: {
                        root.pending = null;
                        psk.text = "";
                    }
                }
            }
        }
    }

    onPendingChanged: if (pending) psk.forceActiveFocus()
}
