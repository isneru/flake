import QtQuick
import "root:/store"

Item {
    id: root

    signal activated

    anchors.fill: parent

    Component.onCompleted: Hints.add(root)
    Component.onDestruction: Hints.remove(root)
}
