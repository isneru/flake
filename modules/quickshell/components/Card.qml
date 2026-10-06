import QtQuick
import "root:/singletons"

Rectangle {
    default property alias content: inner.data
    property int pad: 14
    property alias spacing: inner.spacing

    color: Theme.s1
    radius: Theme.rCard

    Column {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.pad
        spacing: 8
    }
}
