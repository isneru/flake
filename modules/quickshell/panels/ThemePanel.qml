import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var swatchKeys: ["accent", "red", "yellow", "green", "cyan", "blue", "magenta"]

    Tabs {
        Layout.fillWidth: true
        Layout.fillHeight: false
        options: [{ key: "wall", label: "Wallpaper" }, { key: "theme", label: "Themes" }, { key: "shell", label: "Notch" }]
        current: "theme"
        onPicked: k => NotchState.open(k)
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 4
        rowSpacing: 10
        columnSpacing: 10

        Repeater {
            model: Wall.themes

            delegate: Rectangle {
                id: card
                required property string modelData
                readonly property var pal: Wall.palettes[modelData] ?? ({})
                readonly property bool active: Theme.themeName === modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.rCard
                color: pal.bg ?? Theme.s2
                border.width: active ? 2 : 1
                border.color: active ? (pal.accent ?? Theme.accent) : (pal.border ?? Theme.hairline)

                HoverHandler { id: cardHover }
                TapHandler { onTapped: Wall.run(["theme-set", card.modelData]) }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: card.active ? 2 : 1
                    radius: Theme.rCard - 2
                    color: card.pal.bgAlt ?? "transparent"
                    opacity: cardHover.hovered && !card.active ? 0.55 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData
                            font.family: card.pal.mono || Theme.ui
                            font.pixelSize: 12
                            font.weight: card.active ? Font.Medium : Font.Normal
                            color: card.pal.fg ?? Theme.t1
                            elide: Text.ElideRight
                        }
                        Icon {
                            visible: card.active
                            text: "check_circle"
                            size: 14
                            filled: true
                            color: card.pal.accent ?? Theme.accent
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Row {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: root.swatchKeys

                            delegate: Rectangle {
                                required property string modelData
                                width: 13
                                height: 13
                                radius: 6.5
                                color: card.pal[modelData] ?? "transparent"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.09)
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "theme-set - " + Wall.themes.length + " palettes - current is " + Theme.themeName
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
        elide: Text.ElideRight
    }
}
