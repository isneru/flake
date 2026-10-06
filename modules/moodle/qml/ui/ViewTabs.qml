import QtQuick
import "root:/singletons"
import "root:/store"

Item {
    id: root

    property var options: []
    property string current: ""
    signal picked(string key)

    implicitHeight: 34
    readonly property real pad: 9

    Row {
        anchors.left: parent.left
        anchors.leftMargin: -root.pad
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        Repeater {
            model: root.options

            delegate: Item {
                id: tab

                required property var modelData
                readonly property bool active: root.current === tab.modelData.key

                width: lbl.implicitWidth + root.pad * 2
                height: root.height

                HoverHandler {
                    id: hov
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.picked(tab.modelData.key)
                }

                Hint {
                    onActivated: root.picked(tab.modelData.key)
                }

                Text {
                    id: lbl
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: tab.modelData.label
                    font.family: Style.family
                    font.pixelSize: Style.body
                    font.weight: Font.Medium
                    color: tab.active ? Style.text : (hov.hovered ? Style.dim : Style.muted)

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: lbl.implicitWidth
                    height: 2
                    color: Theme.accent
                    opacity: tab.active ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                }
            }
        }
    }
}
