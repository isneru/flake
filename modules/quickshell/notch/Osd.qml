import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "root:/singletons"
import "root:/components"

Item {
    id: root
    readonly property var o: NotchState.osd

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14

        Item {
            visible: root.o.thumb
            Layout.preferredWidth: 56
            Layout.preferredHeight: 34

            Stripes {
                anchors.fill: parent
                radius: 6
                strength: 0.13
                visible: osdShot.status !== Image.Ready
            }
            Image {
                id: osdShot
                anchors.fill: parent
                source: NotchState.osdData.path ? "file://" + NotchState.osdData.path : ""
                sourceSize.width: 112
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
            }
            MultiEffect {
                anchors.fill: osdShot
                source: osdShot
                visible: osdShot.status === Image.Ready
                maskEnabled: true
                maskSource: osdShotMask
                maskThresholdMin: 0.5
            }
            Rectangle {
                id: osdShotMask
                anchors.fill: parent
                radius: 6
                color: "black"
                visible: false
                layer.enabled: true
            }
        }

        Item {
            visible: root.o.art
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38

            Stripes {
                anchors.fill: parent
                radius: 8
                strength: 0.14
                visible: osdArt.status !== Image.Ready
            }
            Image {
                id: osdArt
                anchors.fill: parent
                source: NotchState.osdData.artUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: osdArt
                source: osdArt
                visible: osdArt.status === Image.Ready
                maskEnabled: true
                maskSource: osdArtMask
                maskThresholdMin: 0.5
            }
            Rectangle {
                id: osdArtMask
                anchors.fill: parent
                radius: 8
                color: "black"
                visible: false
                layer.enabled: true
            }
        }

        Icon {
            visible: !root.o.thumb && !root.o.art
            size: 23
            filled: true
            text: root.o.icon
            color: root.o.color
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: root.o.label
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.95)
                    elide: Text.ElideRight
                    Layout.maximumWidth: 220

                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Text {
                    visible: root.o.sub !== ""
                    text: root.o.sub
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.alpha(Theme.t1, 0.48)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Item {
                    visible: root.o.sub === ""
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                visible: root.o.bar
                Layout.fillWidth: true
                height: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.13)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, root.o.pct)) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.o.color
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.2, 1, 1, 1] } }
                }
            }
        }

        Row {
            visible: root.o.eq
            spacing: 2.5
            height: 20
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: 2.5
                    radius: 2
                    color: root.o.color
                    anchors.bottom: parent.bottom
                    height: 4
                    SequentialAnimation on height {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 150 }
                        NumberAnimation { to: 20; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 4; duration: 450; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        Rectangle {
            visible: root.o.save
            Layout.preferredWidth: 62
            Layout.preferredHeight: 26
            radius: 13
            color: saveHover.hovered ? Theme.accent : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }

            HoverHandler { id: saveHover }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: NotchState.saveShot()
            }

            Row {
                anchors.centerIn: parent
                spacing: 5
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 14
                    filled: true
                    text: "download"
                    color: saveHover.hovered ? Theme.fgOnAccent : Theme.t2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Save"
                    font.family: Theme.ui
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: saveHover.hovered ? Theme.fgOnAccent : Theme.t1
                }
            }
        }

        Text {
            visible: root.o.right !== ""
            text: root.o.right
            font.family: Theme.mono
            font.pixelSize: 13
            font.weight: Font.Medium
            color: root.o.color
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
