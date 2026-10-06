import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var all: Bluetooth.devices.values
    readonly property var paired: all.filter(d => d.paired || d.bonded)
    readonly property var nearby: all.filter(d => !(d.paired || d.bonded))
    readonly property bool powered: adapter?.enabled ?? false

    property string armed: ""

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = ""
    }

    Component.onDestruction: if (adapter) adapter.discovering = false

    function stateText(d) {
        if (d.pairing)
            return "pairing…";
        if (d.connected)
            return "connected" + (d.icon ? " - " + d.icon : "");
        return (d.paired || d.bonded) ? "paired - not connected" : (d.icon || "");
    }

    function title(d) {
        const t = Bt.tail(d);
        return Bt.display(d) + (t ? " - " + t : "");
    }

    function deviceIcon(d) {
        const i = d.icon ?? "";
        if (i.includes("headset") || i.includes("headphone"))
            return "headphones";
        if (i.includes("audio"))
            return "speaker";
        if (i.includes("mouse"))
            return "mouse";
        if (i.includes("keyboard"))
            return "keyboard";
        if (i.includes("phone"))
            return "smartphone";
        return "bluetooth";
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 30

        Text {
            text: "PAIRED DEVICES"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Item { Layout.fillWidth: true }

        Rectangle {
            readonly property bool on: root.adapter?.discoverable ?? false
            Layout.preferredWidth: seeRow.implicitWidth + 26
            Layout.preferredHeight: 30
            radius: 15
            visible: root.powered
            color: on ? Theme.accent : (seeHover.hovered ? Theme.s3 : Theme.s2)
            Behavior on color { ColorAnimation { duration: 160 } }
            HoverHandler { id: seeHover }
            TapHandler {
                onTapped: {
                    root.adapter.discoverableTimeout = 180;
                    root.adapter.pairable = true;
                    root.adapter.discoverable = !root.adapter.discoverable;
                }
            }

            Row {
                id: seeRow
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    filled: true
                    text: parent.parent.on ? "visibility" : "visibility_off"
                    color: parent.parent.on ? Theme.fgOnAccent : Theme.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.parent.on ? "Visible" : "Make visible"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: parent.parent.on ? Theme.fgOnAccent : Qt.rgba(1, 1, 1, 0.9)
                }
            }
        }

        Rectangle {
            readonly property bool scanning: root.adapter?.discovering ?? false
            Layout.preferredWidth: scanRow.implicitWidth + 26
            Layout.preferredHeight: 30
            Layout.leftMargin: 8
            radius: 15
            visible: root.powered
            color: scanHover.hovered ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            HoverHandler { id: scanHover }
            TapHandler {
                onTapped: root.adapter.discovering = !root.adapter.discovering
            }

            Row {
                id: scanRow
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    filled: true
                    text: parent.parent.scanning ? "progress_activity" : "bluetooth"
                    color: Theme.accent
                    RotationAnimation on rotation {
                        running: scanRow.parent.scanning
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.parent.scanning ? "Scanning…" : "Scan"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.9)
                }
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 174)
        Layout.fillHeight: false
        visible: root.powered && root.paired.length > 0
        clip: true
        spacing: 8
        model: root.paired
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: dev
            required property var modelData
            width: ListView.view.width
            height: 50
            radius: 12
            color: Theme.s1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 9
                    color: Theme.s2
                    Icon {
                        anchors.centerIn: parent
                        size: 17
                        filled: true
                        text: root.deviceIcon(dev.modelData)
                        color: dev.modelData.connected ? Theme.accent : Theme.t2
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: root.title(dev.modelData)
                        font.family: Theme.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.t1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.stateText(dev.modelData)
                        font.family: Theme.ui
                        font.pixelSize: 10
                        color: Theme.t3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                Text {
                    visible: dev.modelData.batteryAvailable
                    text: Math.round((dev.modelData.battery ?? 0) * 100) + "%"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.t2
                }
                Icon {
                    size: 18
                    text: dev.modelData.trusted ? "verified_user" : "gpp_maybe"
                    color: dev.modelData.trusted ? Theme.success : Theme.t3
                    TapHandler { onTapped: dev.modelData.trusted = !dev.modelData.trusted }
                }
                Icon {
                    size: 18
                    text: dev.modelData.connected ? "link" : "link_off"
                    color: dev.modelData.connected ? Theme.accent : Theme.t3
                    TapHandler {
                        onTapped: dev.modelData.connected ? dev.modelData.disconnect() : dev.modelData.connect()
                    }
                }
                Rectangle {
                    readonly property bool isArmed: root.armed === dev.modelData.address
                    Layout.preferredWidth: isArmed ? gone.implicitWidth + 20 : 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: isArmed ? Theme.error : (dropHover.hovered ? Theme.s3 : Theme.s2)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    HoverHandler { id: dropHover }
                    TapHandler {
                        onTapped: {
                            if (root.armed !== dev.modelData.address) {
                                root.armed = dev.modelData.address;
                                disarm.restart();
                                return;
                            }
                            root.armed = "";
                            dev.modelData.forget();
                        }
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: root.armed !== dev.modelData.address
                        size: 15
                        text: "delete"
                        color: Theme.t2
                    }
                    Text {
                        id: gone
                        anchors.centerIn: parent
                        visible: root.armed === dev.modelData.address
                        text: "Unpair?"
                        font.family: Theme.ui
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.fgOnAccent
                    }
                }
            }
        }
    }

    Text {
        visible: root.powered && root.paired.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: "No paired devices"
        font.family: Theme.ui
        font.pixelSize: 12
        color: Theme.t4
    }

    Text {
        visible: root.powered
        Layout.topMargin: 6
        text: "NEARBY"
        font.family: Theme.ui
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.55
        color: Theme.t3
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.powered

        Column {
            anchors.centerIn: parent
            spacing: 8
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 30
                text: "bluetooth_disabled"
                color: Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t3
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.adapter !== null
                width: 96
                height: 30
                radius: 15
                color: onHover.hovered ? Theme.accent : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }
                HoverHandler { id: onHover }
                TapHandler { onTapped: NotchState.toggle("bt") }
                Text {
                    anchors.centerIn: parent
                    text: "Turn on"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: onHover.hovered ? Theme.fgOnAccent : Theme.t1
                }
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.powered && root.nearby.length > 0
        clip: true
        spacing: 8
        model: root.nearby
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: near
            required property var modelData
            width: ListView.view.width
            height: 44
            radius: 12
            color: Theme.s1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 12

                Icon {
                    size: 17
                    filled: true
                    text: root.deviceIcon(near.modelData)
                    color: Theme.t2
                }
                Text {
                    Layout.fillWidth: true
                    text: root.title(near.modelData)
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.t1
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 28
                    radius: 14
                    color: near.modelData.pairing ? Theme.s3 : Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: near.modelData.pairing ? "Cancel" : "Pair"
                        font.family: Theme.ui
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: near.modelData.pairing ? Theme.t2 : Theme.fgOnAccent
                    }
                    TapHandler {
                        onTapped: near.modelData.pairing ? near.modelData.cancelPair() : near.modelData.pair()
                    }
                }
            }
        }
    }

    Text {
        visible: root.powered && root.nearby.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        text: (root.adapter?.discovering ?? false) ? "Scanning…" : "Hit Scan to look for devices"
        font.family: Theme.ui
        font.pixelSize: 12
        color: Theme.t4
    }
}
