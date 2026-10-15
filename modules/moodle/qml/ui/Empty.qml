import QtQuick
import "root:/singletons"
import "root:/store"
import "root:/components"

Column {
    id: root

    property string glyph: "inbox"
    property string title: ""
    property string detail: ""

    spacing: 8

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.glyph
        size: 30
        color: Style.faint
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.title
        font.family: Style.family
        font.pixelSize: Style.row
        font.weight: Font.Medium
        color: Style.muted
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.detail
        text: root.detail
        horizontalAlignment: Text.AlignHCenter
        font.family: Style.family
        font.pixelSize: Style.body
        color: Style.faint
    }
}
