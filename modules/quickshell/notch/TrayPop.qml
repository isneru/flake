import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"
import "root:/components"

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property var items: Tray.items.values
    property bool pinned: false
    property var hovered: null

    readonly property var manage: ({ tooltipTitle: "Manage tray processes" })

    anchors { top: true; right: true }
    implicitWidth: 560
    implicitHeight: 140
    color: "transparent"
    visible: items.length > 0 && !NotchState.hidden && !Lock.active

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-tray"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: tab }

    Timer {
        id: unpin
        interval: 5000
        onTriggered: win.pinned = false
    }
    function menu(item, mouse, area) {
        const p = area.mapToItem(null, mouse.x, mouse.y);
        item.display(win, Math.round(p.x), Math.round(p.y));
        pinned = true;
        unpin.restart();
    }

    EdgeTab {
        id: tab
        edge: "top"
        corner: "right"
        window: win
        anchors.top: parent.top
        anchors.right: parent.right

        tint: NotchState.floating ? Theme.notchGlass : "#000000"

        pinned: win.pinned
        onHoveredChanged: if (hovered) win.pinned = false

        openLength: row.implicitWidth + 18
        openDepth: NotchState.collapsedH

        content: Row {
            id: row
            anchors.centerIn: parent
            spacing: 3
            opacity: tab.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: Tray.items

                delegate: Rectangle {
                    id: cell
                    required property var modelData

                    width: 26
                    height: 26
                    radius: 9
                    color: cellHover.hovered ? Theme.s3 : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    HoverHandler {
                        id: cellHover
                        enabled: tab.open
                        onHoveredChanged: {
                            if (hovered)
                                win.hovered = cell.modelData;
                            else if (win.hovered === cell.modelData)
                                win.hovered = null;
                        }
                    }

                    Image {
                        id: img
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                        source: cell.modelData.icon
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        size: 16
                        filled: true
                        text: "widgets"
                        color: Theme.t3
                        visible: !img.visible
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        enabled: tab.open
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            const it = cell.modelData;
                            if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && it.onlyMenu)) {
                                if (it.hasMenu)
                                    win.menu(it, mouse, area);
                                else if (mouse.button === Qt.RightButton)
                                    it.secondaryActivate();
                            } else if (mouse.button === Qt.MiddleButton) {
                                it.secondaryActivate();
                            } else {
                                it.activate();
                            }
                        }
                        onWheel: wheel => {
                            const d = wheel.angleDelta;
                            if (d.y)
                                cell.modelData.scroll(d.y, false);
                            if (d.x)
                                cell.modelData.scroll(d.x, true);
                        }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: Theme.hairline
            }

            Rectangle {
                width: 26
                height: 26
                radius: 9
                color: manageHover.hovered ? Theme.s3 : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }

                HoverHandler {
                    id: manageHover
                    enabled: tab.open
                    onHoveredChanged: win.hovered = hovered ? win.manage : (win.hovered === win.manage ? null : win.hovered)
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: tab.open
                    onClicked: NotchState.open("tray")
                }
                Icon {
                    anchors.centerIn: parent
                    size: 16
                    filled: true
                    text: "more_horiz"
                    color: Theme.t3
                }
            }
        }
    }

    Rectangle {
        id: tip
        anchors.right: tab.right
        anchors.rightMargin: tab.fillet
        anchors.top: tab.bottom
        anchors.topMargin: 6
        width: tipText.width + 20
        height: 26
        radius: 9
        color: Theme.notchGlass
        visible: opacity > 0
        opacity: tab.open && win.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Text {
            id: tipText
            anchors.centerIn: parent
            width: Math.min(300, implicitWidth)
            text: win.hovered ? (win.hovered.tooltipTitle || win.hovered.title || win.hovered.id) : ""
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Theme.t1
            elide: Text.ElideRight
        }
    }
}
