import QtQuick
import "root:/singletons"

Rectangle {
    id: root
    property var options: []
    property string current: ""
    signal picked(string key)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 40
    radius: 13
    color: Qt.rgba(0, 0, 0, 0.35)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool active: root.current === modelData.key
                height: 32
                width: label.implicitWidth + 30
                radius: 10
                color: active ? "#ffffff" : "transparent"
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: parent.active ? Theme.fgOnAccent : Theme.t2
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(parent.modelData.key)
                }
            }
        }
    }
}
