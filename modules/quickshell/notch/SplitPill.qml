import QtQuick
import Quickshell.Services.UPower
import "root:/singletons"

Item {
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: clockText.implicitWidth + 26
        radius: 14
        color: Theme.notchSplit

        Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.mono
            font.pixelSize: 14
            font.weight: Font.Medium
            font.letterSpacing: 0.6
            color: Theme.t1
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: statusRow.implicitWidth + 24
        radius: 14
        color: Theme.notchSplit

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                text: NotchState.toggles.wifi ? "wifi" : "wifi_off"
                font.family: Theme.icons
                font.pixelSize: 15
                font.variableAxes: ({ FILL: 1, wght: 350 })
                color: Qt.rgba(1, 1, 1, 0.8)
            }
            Text {
                readonly property int pct: Math.round((UPower.displayDevice.percentage ?? 0) * 100)
                readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
                text: charging ? "battery_charging_full" : (pct <= 10 ? "battery_alert" : "battery_" + Math.max(1, Math.min(6, Math.round(pct / 100 * 6))) + "_bar")
                font.family: Theme.icons
                font.pixelSize: 15
                font.variableAxes: ({ FILL: 1, wght: 350 })
                color: charging ? Theme.success : (pct <= 15 ? Theme.warning : Theme.accent)
            }
        }
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: date = new Date()
    }
}
