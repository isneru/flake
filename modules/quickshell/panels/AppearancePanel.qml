import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 11

    component Row2: Rectangle {
        id: row
        property string title: ""
        property string desc: ""
        property string hint: ""
        property var options: []
        property string current: ""
        signal picked(string key)

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.rCard
        color: Theme.s1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: row.title
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.t1
                }
                Text {
                    text: row.desc
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.alpha(Theme.t1, 0.45)
                }
                Text {
                    text: row.hint
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                    topPadding: 3
                }
            }

            Item { Layout.fillWidth: true }

            Segmented {
                options: row.options
                current: row.current
                onPicked: k => row.picked(k)
            }
        }
    }

    Tabs {
        Layout.fillWidth: true
        Layout.fillHeight: false
        options: [{ key: "wall", label: "Wallpaper" }, { key: "theme", label: "Themes" }, { key: "shell", label: "Notch" }]
        current: "shell"
        onPicked: k => NotchState.open(k)
    }

    Row2 {
        title: "Collapsed pill"
        desc: "how the notch sits at rest"
        hint: "pillStyle - default notch"
        current: Config.pillStyle
        options: [
            { key: "notch", label: "Notch" },
            { key: "inset", label: "Floating pill" },
            { key: "split", label: "Split lozenges" }
        ]
        onPicked: k => Config.setPill(k)
    }

    Row2 {
        title: "Expansion"
        desc: "morph curve when it opens"
        hint: "expandAnim - default spring"
        current: Config.expandAnim
        options: [
            { key: "spring", label: "Spring" },
            { key: "unfold", label: "Unfold" },
            { key: "liquid", label: "Liquid" }
        ]
        onPicked: k => Config.setAnim(k)
    }

    Row2 {
        title: "Control centre layout"
        desc: "how the toggles are presented"
        hint: "ccLayout - default grid"
        current: Config.ccLayout
        options: [
            { key: "grid", label: "Tiles" },
            { key: "rows", label: "Rows" }
        ]
        onPicked: k => Config.setCc(k)
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: 13
        color: Qt.rgba(1, 1, 1, 0.035)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: "notch.json → " + Config.summary
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.alpha(Theme.t1, 0.4)
                elide: Text.ElideMiddle
            }
            Rectangle {
                height: 28
                width: resetLabel.implicitWidth + 26
                radius: 14
                color: rh.hovered ? Theme.s4 : Theme.s2
                HoverHandler { id: rh }
                TapHandler { onTapped: Config.reset() }
                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: "Reset to defaults"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.alpha(Theme.t1, 0.75)
                }
            }
        }
    }
}
