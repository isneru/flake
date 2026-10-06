import QtQuick
import "root:/singletons"

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
                readonly property bool active: root.current === modelData.key

                width: lbl.implicitWidth + root.pad * 2
                height: root.height

                HoverHandler { id: hov }
                TapHandler { onTapped: root.picked(tab.modelData.key) }

                Text {
                    id: lbl
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: tab.modelData.label
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: tab.active ? Theme.t1 : (hov.hovered ? Theme.t2 : Theme.t3)
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: lbl.implicitWidth
                    height: 2
                    radius: 1
                    color: Theme.accent
                    opacity: tab.active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }
        }
    }
}
