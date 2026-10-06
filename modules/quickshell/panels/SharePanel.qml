import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    property string tab: "screen"

    Component.onDestruction: Screencast.cancelAll()

    Connections {
        target: Screencast
        function onPendingChanged() {
            if (!Screencast.pending)
                NotchState.close();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        Layout.fillHeight: false

        Tabs {
            Layout.fillWidth: true
            options: [
                { key: "screen", label: "Screen" },
                { key: "window", label: "Window" },
                { key: "region", label: "Region" }
            ]
            current: root.tab
            onPicked: k => root.tab = k
        }

        Text {
            visible: Screencast.queue.length > 1
            text: "+" + (Screencast.queue.length - 1) + " waiting"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.t3
        }
    }


    Item {
        id: screens
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.tab === "screen"

        Row {
            anchors.centerIn: parent
            spacing: 11

            Repeater {
                model: Quickshell.screens

                delegate: SourceTile {
                    id: screenTile
                    required property var modelData
                    height: screens.height
                    width: Math.min(screens.width, height * screenTile.modelData.width / screenTile.modelData.height + 20)
                    source: screenTile.modelData
                    label: screenTile.modelData.name
                    sub: screenTile.modelData.width + "×" + screenTile.modelData.height
                    glyph: "desktop_windows"
                    onChosen: Screencast.pick("screen:" + screenTile.modelData.name)
                }
            }
        }
    }


    GridView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.tab === "window"
        clip: true
        cellWidth: Math.floor(width / 3)
        cellHeight: 152
        model: Screencast.windows

        delegate: Item {
            id: cell
            required property var modelData
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            SourceTile {
                anchors.fill: parent
                anchors.rightMargin: 11
                anchors.bottomMargin: 11
                source: Screencast.toplevelFor(cell.modelData)
                icon: cell.modelData.appId
                label: cell.modelData.title || cell.modelData.appId
                sub: cell.modelData.appId
                glyph: "web_asset"
                onChosen: Screencast.pick("window:" + cell.modelData.handle)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: Screencast.windows.length === 0
            text: "No windows to share"
            font.family: Theme.ui
            font.pixelSize: 13
            color: Theme.t3
        }
    }


    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.tab === "region"
        radius: Theme.rCard
        color: regionArea.containsMouse ? Theme.s2 : Theme.s1
        Behavior on color { ColorAnimation { duration: 160 } }

        Column {
            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 40
                text: Screencast.picking ? "highlight_alt" : "crop_free"
                color: Theme.t2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Screencast.picking ? "Drag a region…" : "Select a region"
                font.family: Theme.ui
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Theme.t1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "slurp - shares the area, not the window under it"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.t4
            }
        }

        MouseArea {
            id: regionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Screencast.pickRegion()
        }
    }


    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.fillHeight: false
        spacing: 12

        Rectangle {
            Layout.preferredWidth: tokenRow.implicitWidth + 28
            Layout.preferredHeight: 44
            radius: 13
            color: Screencast.pickToken ? Theme.alpha(Theme.accent, 0.16) : (tokenArea.containsMouse ? Theme.s2 : Theme.s1)
            Behavior on color { ColorAnimation { duration: 160 } }

            Row {
                id: tokenRow
                anchors.centerIn: parent
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 17
                    filled: Screencast.pickToken
                    text: Screencast.pickToken ? "lock_open" : "lock"
                    color: Screencast.pickToken ? Theme.accent : Theme.t3
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Let this app share again without asking"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    color: Screencast.pickToken ? Theme.t1 : Theme.t2
                }
            }

            MouseArea {
                id: tokenArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Screencast.pickToken = !Screencast.pickToken
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            Layout.preferredWidth: 160
            Layout.preferredHeight: 44
            radius: 13
            color: denyArea.containsMouse ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: "Deny"
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.t1
            }
            MouseArea {
                id: denyArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Screencast.cancel()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "xdg-desktop-portal-hyprland - picking a source starts sharing it"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
        elide: Text.ElideRight
    }
}
