import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

RowLayout {
    id: root
    spacing: 16

    Component.onCompleted: {
        Sensors.watchers++;
        Sensors.procWatchers++;
    }
    Component.onDestruction: {
        Sensors.watchers--;
        Sensors.procWatchers--;
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        Repeater {
            model: [
                { k: "cpu", label: "CPU", unit: "%", c: Theme.accent },
                { k: "ram", label: "Memory", unit: "%", c: Theme.success },
                { k: "disk", label: "Disk", unit: "%", c: Theme.warning },
                { k: "temp", label: "Temperature", unit: "°C", c: Theme.info }
            ]
            delegate: Rectangle {
                id: meter
                required property var modelData
                readonly property int value: Sensors[modelData.k]

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.rCard
                color: Theme.s1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: meter.modelData.label
                            font.family: Theme.ui
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.t1
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: meter.value + meter.modelData.unit
                            font.family: Theme.mono
                            font.pixelSize: 13
                            color: Theme.t2
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.track
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
                            height: parent.height
                            radius: parent.radius
                            color: meter.modelData.c
                            Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.Bezier; easing.bezierCurve: [0.3, 0.9, 0.3, 1, 1, 1] } }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.preferredWidth: 262
        Layout.fillWidth: false
        Layout.fillHeight: true
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            Layout.fillHeight: false
            radius: Theme.rCard
            color: Theme.s1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Icon { size: 16; text: "arrow_downward"; color: Theme.accent }
                    Text {
                        Layout.fillWidth: true
                        text: Sensors.netDown.toFixed(2) + " MB/s"
                        font.family: Theme.mono
                        font.pixelSize: 13
                        color: Theme.t1
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Icon { size: 16; text: "arrow_upward"; color: Theme.success }
                    Text {
                        Layout.fillWidth: true
                        text: Sensors.netUp.toFixed(2) + " MB/s"
                        font.family: Theme.mono
                        font.pixelSize: 13
                        color: Theme.t1
                    }
                }
            }
        }

        Text {
            text: "TOP PROCESSES"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: Theme.s1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9

                Repeater {
                    model: Sensors.procs
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.t2
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.cpu + "%"
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.accent
                        }
                        Text {
                            Layout.preferredWidth: 52
                            horizontalAlignment: Text.AlignRight
                            text: modelData.mem + " MB"
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.t3
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
