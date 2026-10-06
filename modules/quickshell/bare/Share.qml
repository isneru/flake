import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    visible: Screencast.pending && !Screencast.picking
    color: Theme.alpha(Theme.bgDim, 0.55)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bare-share"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var rows: {
        const out = [];
        for (const s of Quickshell.screens)
            out.push({ sel: "screen:" + s.name, label: `[${s.name}]: "${s.width}×${s.height}"` });
        for (const w of Screencast.windows)
            out.push({ sel: "window:" + w.handle, label: `[${Menu.short(w.appId) || "?"}]: "${w.title || ""}"` });
        return out;
    }

    onVisibleChanged: if (visible) {
        list.currentIndex = 0;
        list.forceActiveFocus();
    }

    Rectangle {
        anchors.centerIn: parent
        width: 620
        height: Math.min(460, head.implicitHeight + list.contentHeight + foot.implicitHeight + 40)
        radius: 0
        color: Theme.alpha(Theme.bgDim, 0.94)
        border.width: 1
        border.color: Theme.border

        Text {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            text: "SHARE A SOURCE  [" + (Menu.short(Screencast.req?.appId ?? "") || "unknown") + "]"
            color: Theme.accent
            elide: Text.ElideRight
            font.family: Theme.themeMono
            font.pixelSize: Theme.themeSize - 2
            renderType: Text.NativeRendering
        }

        ListView {
            id: list
            anchors.top: head.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: foot.top
            anchors.margins: 12
            clip: true
            model: root.rows
            focus: true

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width
                height: Theme.themeSize + 10
                radius: 0
                color: index === list.currentIndex ? Theme.accent : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 12
                    text: modelData.label
                    elide: Text.ElideRight
                    color: index === list.currentIndex ? Theme.bg : Theme.fg
                    font.family: Theme.themeMono
                    font.pixelSize: Theme.themeSize
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        list.currentIndex = index;
                        Screencast.pick(modelData.sel);
                    }
                }
            }

            Keys.onReturnPressed: root.accept()
            Keys.onEnterPressed: root.accept()
            Keys.onEscapePressed: Screencast.cancel()
        }

        Text {
            id: foot
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            text: "[Enter] share    [r] region    [Esc] deny"
            color: Theme.fgMuted
            font.family: Theme.themeMono
            font.pixelSize: Theme.themeSize - 2
            renderType: Text.NativeRendering
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_R) {
                Screencast.pickRegion();
                event.accepted = true;
            }
        }
    }

    function accept() {
        const r = rows[list.currentIndex];
        if (r)
            Screencast.pick(r.sel);
    }
}
