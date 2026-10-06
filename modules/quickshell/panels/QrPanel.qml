import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 24

        Text {
            text: Qr.hasResult ? Qr.kind.toUpperCase() : "QR SCANNER"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Qr.hasResult ? Theme.success : Theme.t3
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Qr.hasResult ? Qr.text.length + " characters" : ""
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.t4
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.rCard
        color: Theme.s1

        Column {
            anchors.centerIn: parent
            visible: !Qr.hasResult
            spacing: 9

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 32
                text: Qr.scanning ? "crop_free" : (Qr.error ? "search_off" : "qr_code_scanner")
                color: Qr.error ? Theme.warning : Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qr.scanning ? "select a region…" : (Qr.error || "Scan a QR code on screen")
                font.family: Theme.ui
                font.pixelSize: 13
                color: Qr.error ? Theme.warning : Theme.t3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "decoded in memory - copied to the clipboard"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            visible: Qr.hasResult
            contentWidth: width
            contentHeight: result.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: result
                width: parent.width
                text: Qr.text
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                font.family: Theme.mono
                font.pixelSize: 14
                color: Theme.t1
                selectionColor: Theme.accent
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        Layout.fillHeight: false
        spacing: 9

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 13
            color: Theme.accent
            opacity: scanArea.containsMouse ? 0.88 : 1

            Row {
                anchors.centerIn: parent
                spacing: 9
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 17
                    filled: true
                    text: "qr_code_scanner"
                    color: Theme.fgOnAccent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qr.hasResult ? "Scan another" : "Select region"
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.fgOnAccent
                }
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qr.scan()
            }
        }

        Rectangle {
            Layout.preferredWidth: 150
            Layout.preferredHeight: 42
            radius: 13
            color: clearArea.containsMouse ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            opacity: Qr.hasResult ? 1 : 0.4

            Text {
                anchors.centerIn: parent
                text: "Forget"
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.t1
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: Qr.hasResult
                cursorShape: Qt.PointingHandCursor
                onClicked: Qr.clear()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "zbar - decoded in memory and copied to the clipboard"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
