import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10


    Tabs {
        Layout.fillWidth: true
        Layout.fillHeight: false
        options: [{ key: "wifi", label: "Wi-Fi" }, { key: "net", label: "Stats" }]
        current: "net"
        onPicked: k => NotchState.open(k)
    }

    Component.onCompleted: Net.watching = true
    Component.onDestruction: {
        Net.watching = false;
        Net.clearQr();
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 24

        Text {
            text: NotchState.networkName ? NotchState.networkName.toUpperCase() : "OFFLINE"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Net.iface
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.t4
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 74
        Layout.fillHeight: false
        spacing: 10

        Repeater {
            model: [
                { icon: "south", label: "Down", value: Net.fmtRate(Net.rxRate), c: Theme.accent },
                { icon: "north", label: "Up", value: Net.fmtRate(Net.txRate), c: Theme.success }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.rCard
                color: Theme.s1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    Icon {
                        size: 22
                        filled: true
                        text: parent.parent.modelData.icon
                        color: parent.parent.modelData.c
                    }
                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: parent.parent.parent.modelData.label
                            font.family: Theme.ui
                            font.pixelSize: 11
                            color: Theme.t3
                        }
                        Text {
                            text: parent.parent.parent.modelData.value
                            font.family: Theme.mono
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: Theme.t1
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 74
        Layout.fillHeight: false
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: pingArea.containsMouse ? Theme.s2 : Theme.s1
            Behavior on color { ColorAnimation { duration: 160 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Net.pinging ? "pinging…"
                        : (Net.pingMs >= 0 ? Net.pingMs + " ms" : "Ping")
                    font.family: Net.pingMs >= 0 && !Net.pinging ? Theme.mono : Theme.ui
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: Theme.t1
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Net.pingLoss >= 0 ? Net.pingLoss + "% loss - 1.1.1.1" : "tap to measure latency"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Net.pingLoss > 0 ? Theme.warning : Theme.t4
                }
            }

            MouseArea {
                id: pingArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Net.runPing()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: speedArea.containsMouse ? Theme.s2 : Theme.s1
            Behavior on color { ColorAnimation { duration: 160 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Net.testing ? "testing…"
                        : (Net.downMbps > 0 ? Net.downMbps.toFixed(1) + " Mb/s" : "Speed test")
                    font.family: Net.downMbps > 0 && !Net.testing ? Theme.mono : Theme.ui
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: Theme.t1
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Net.testing ? "downloading 30 MB" : "cloudflare - download only"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                }
            }

            MouseArea {
                id: speedArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Net.runSpeed()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 22
        Layout.fillHeight: false
        Text {
            text: "DNS"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Net.dns
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.t4
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        Layout.fillHeight: false
        spacing: 8

        Repeater {
            model: Net.dnsPresets
            delegate: Rectangle {
                id: preset
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 12
                color: dnsArea.containsMouse ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: 160 } }
                opacity: Net.dnsBusy === "" || Net.dnsBusy === modelData.label ? 1 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: Net.dnsBusy === preset.modelData.label ? "applying…" : preset.modelData.label
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.t1
                }

                MouseArea {
                    id: dnsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Net.setDns(preset.modelData.label, preset.modelData.servers)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        Layout.fillHeight: false
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 13
            color: qrArea.containsMouse ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            opacity: NotchState.ssid ? 1 : 0.4

            Row {
                anchors.centerIn: parent
                spacing: 9
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 17
                    text: NotchState.ssid ? "qr_code_2" : "wifi_off"
                    color: Theme.t2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !NotchState.ssid ? "Not on Wi-Fi — nothing to share"
                        : (Net.qrBusy ? "reading passphrase…"
                        : (Net.qrError ? Net.qrError : "Share " + NotchState.ssid + " as QR"))
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Net.qrError ? Theme.warning : (NotchState.ssid ? Theme.t1 : Theme.t3)
                }
            }

            MouseArea {
                id: qrArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: NotchState.ssid !== ""
                cursorShape: Qt.PointingHandCursor
                onClicked: Net.qrPath ? Net.clearQr() : Net.makeQr()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "rates read from sysfs - DNS changes need authorization"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }

    Rectangle {
        parent: root.parent
        anchors.centerIn: parent
        visible: Net.qrPath !== ""
        width: 300
        height: 340
        radius: Theme.rCard
        color: Theme.notchSolid
        border.width: 1
        border.color: Theme.hairline

        Column {
            anchors.centerIn: parent
            spacing: 12

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 244
                height: 244
                radius: 10
                color: "white"
                Image {
                    anchors.centerIn: parent
                    width: 228
                    height: 228
                    source: Net.qrPath ? "file://" + Net.qrPath : ""
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    smooth: false
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: NotchState.ssid
                font.family: Theme.ui
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Theme.t1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "scan to join - tap to close"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Net.clearQr()
        }
    }
}
