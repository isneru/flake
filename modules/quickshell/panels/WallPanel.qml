import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    spacing: 12

    Tabs {
        Layout.fillWidth: true
        Layout.fillHeight: false
        options: [{ key: "wall", label: "Wallpaper" }, { key: "theme", label: "Themes" }, { key: "shell", label: "Notch" }]
        current: "wall"
        onPicked: k => NotchState.open(k)
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 4
        rowSpacing: 10
        columnSpacing: 10

        Repeater {
            model: Wall.papers.slice(0, 8)

            delegate: Rectangle {
                id: thumb
                required property string modelData
                readonly property bool active: Wall.source === modelData
                readonly property string preview: Wall.previewDir + "/" + Wall.previewTheme + "/" + modelData.split("/").pop()

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Theme.s2
                border.width: active ? 2 : 0
                border.color: Theme.accent
                TapHandler { onTapped: Wall.applyPaper(thumb.modelData) }

                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: thumb.active ? 2 : 0
                    visible: false
                    layer.enabled: true

                    Image {
                        anchors.fill: parent
                        source: "file://" + thumb.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                    }
                    Image {
                        id: tinted
                        anchors.fill: parent

                        source: Wall.recolor && Wall.previewTheme !== "" ? "file://" + thumb.preview : ""
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        height: 20
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            text: thumb.modelData.split("/").pop()
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.t2
                            elide: Text.ElideMiddle
                            width: parent.width - 14
                        }
                    }
                }
                MultiEffect {
                    anchors.fill: content
                    source: content
                    maskEnabled: true
                    maskSource: thumbMask
                    maskThresholdMin: 0.5
                }
                Rectangle {
                    id: thumbMask
                    anchors.fill: content

                    radius: thumb.active ? 10 : 12
                    color: "black"
                    visible: false
                    layer.enabled: true
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 64
        radius: Theme.rCard
        color: Theme.s1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    text: "RECOLOR"
                    font.family: Theme.ui
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 0.55
                    color: Theme.t3
                }
                Text {
                    text: Wall.picked ? (Wall.recolor ? "re-tinted on every theme switch" : "shown as-is") : "pick a wallpaper first"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                }
            }

            Toggle {
                Layout.alignment: Qt.AlignVCenter
                checked: Wall.recolor
                opacity: Wall.picked ? 1 : 0.35
                onToggled: Wall.setRecolor(!Wall.recolor)
            }

            Item { Layout.fillWidth: true }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 10
                Repeater {
                    model: [Theme.accent, Theme.success, Theme.warning, Theme.error, Theme.info]
                    delegate: Rectangle {
                        required property var modelData
                        width: 22
                        height: 22
                        radius: 11
                        color: modelData
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                visible: Wall.picked
                height: 28
                width: resetLabel.implicitWidth + 24
                radius: 14
                color: resetHover.hovered ? Theme.s4 : Theme.s2
                HoverHandler { id: resetHover }
                TapHandler { onTapped: Wall.run(["theme-set", "wallpaper-reset"]) }
                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: "Reset"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.alpha(Theme.t1, 0.75)
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "theme-set - " + Wall.papers.length + " wallpapers in ~/pictures/wallpapers"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
        elide: Text.ElideRight
    }
}
