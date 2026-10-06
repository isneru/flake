import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

Item {
    id: root
    readonly property var d: NotchState.osdData
    readonly property color tint: d.urgent ? Theme.error : Theme.accent

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 13

        Item {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: Theme.alpha(Theme.t1, 0.08)
                clip: true

                Image {
                    anchors.fill: parent
                    visible: source != ""
                    source: root.d.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 72
                    sourceSize.height: 72
                    asynchronous: true
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !(root.d.image ?? "")
                    size: 19
                    filled: true
                    text: root.d.icon ?? "notifications"
                    color: root.tint
                }
            }

            Badge {
                visible: (root.d.stack ?? 1) > 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -6
                anchors.topMargin: -5
                size: 18
                tint: root.tint
                text: "+" + ((root.d.stack ?? 1) - 1)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: (root.d.app ?? "").toUpperCase()
                font.family: Theme.mono
                font.pixelSize: 10
                font.letterSpacing: 0.85
                color: root.tint
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: root.d.title ?? ""
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.t1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: (root.d.body ?? "") !== ""
                text: root.d.body ?? ""
                font.family: Theme.ui
                font.pixelSize: 12
                color: Theme.alpha(Theme.t1, 0.55)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            visible: (root.d.action ?? "") !== ""
            height: 28
            width: actLabel.implicitWidth + 24
            radius: 14
            color: ah.hovered ? Theme.alpha(Theme.t1, 0.18) : Theme.alpha(Theme.t1, 0.11)
            HoverHandler { id: ah }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: Notifs.invokePrimary(Notifs.current)
            }
            Text {
                id: actLabel
                anchors.centerIn: parent
                text: root.d.action ?? ""
                font.family: Theme.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: dh.hovered ? Theme.alpha(Theme.t1, 0.12) : Theme.alpha(Theme.t1, 0.05)
            HoverHandler { id: dh }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: Notifs.dismiss(Notifs.current)
            }
            Icon {
                anchors.centerIn: parent
                size: 16
                text: "close"
                color: Theme.alpha(Theme.t1, 0.5)
            }
        }
    }

    opacity: 0
    y: -6
    scale: 0.94
    Component.onCompleted: { opacity = 1; y = 0; scale = 1; }
    Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.2, 1, 1, 1] } }
    Behavior on y { NumberAnimation { duration: 380 } }
    Behavior on scale { NumberAnimation { duration: 380 } }
}
