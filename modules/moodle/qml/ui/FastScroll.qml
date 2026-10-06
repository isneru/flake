import QtQuick

MouseArea {
    id: root

    property Flickable view: null
    property real factor: 2

    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    z: 10

    function settle(): void {
        if (root.view)
            root.view.returnToBounds();
    }

    onWheel: wheel => {
        const view = root.view;
        const delta = wheel.angleDelta.y || wheel.angleDelta.x;
        const span = view ? view.contentHeight - view.height : 0;
        if (span <= 0 || !delta || !(wheel.modifiers & Qt.AltModifier)) {
            wheel.accepted = false;
            return;
        }
        const lo = view.originY;
        view.contentY = Math.max(lo, Math.min(lo + span, view.contentY - delta * root.factor));
        Qt.callLater(root.settle);
    }
}
