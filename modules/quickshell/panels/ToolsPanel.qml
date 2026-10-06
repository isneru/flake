import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    readonly property var groups: [
        {
            title: "UTILITIES",
            tiles: [
                { key: "clip", icon: "content_paste", label: "Clipboard", c: Theme.accent },
                { key: "shelf", icon: "inbox", label: "Shelf", c: Theme.success },
                { key: "send", icon: "wifi_tethering", label: "LocalSend", c: Theme.accent },
                { key: "timer", icon: "timer", label: "Timer", c: Theme.warning },
                { key: "weather", icon: "partly_cloudy_day", label: "Weather", c: Theme.accent },
                { key: "keys", icon: "keyboard", label: "Keys", c: Theme.info }
            ]
        },
        {
            title: "SYSTEM",
            tiles: [
                { key: "monitor", icon: "monitor_heart", label: "Monitor", c: Theme.success },
                { key: "display", icon: "desktop_windows", label: "Displays", c: Theme.accent },
                { key: "audio", icon: "graphic_eq", label: "Audio", c: Theme.accent },
                { key: "wifi", icon: "wifi", label: "Network", c: Theme.accent },
                { key: "bt", icon: "bluetooth", label: "Bluetooth", c: Theme.accent },
                { key: "wall", icon: "palette", label: "Appearance", c: Theme.info }
            ]
        }
    ]

    Repeater {
        model: root.groups

        delegate: ColumnLayout {
            id: grp
            required property var modelData
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Text {
                text: grp.modelData.title
                font.family: Theme.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.55
                color: Theme.t3
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 4
                rowSpacing: 11
                columnSpacing: 11

                Repeater {
                    model: grp.modelData.tiles

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 15
                        color: hov.hovered ? Theme.s3 : Theme.s2
                        Behavior on color { ColorAnimation { duration: 200 } }
                        HoverHandler { id: hov }
                        TapHandler { onTapped: NotchState.open(modelData.key) }

                        Badge {
                            visible: modelData.key === "send" && LocalSend.incoming.length > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            tint: Theme.accent
                            text: LocalSend.incoming.length
                        }

                        Badge {
                            visible: modelData.key === "shelf" && Shelf.count > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            tint: Theme.success
                            text: Shelf.count
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 9
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 26
                                filled: true
                                weight: 300
                                crisp: modelData.key !== "weather"
                                text: modelData.icon
                                color: modelData.c
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.family: Theme.ui
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.85)
                            }
                        }
                    }
                }
            }
        }
    }
}
