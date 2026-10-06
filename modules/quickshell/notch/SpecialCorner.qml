import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/singletons"
import "root:/components"

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property string monName: Hyprland.monitorFor(modelData)?.name ?? ""
    property string special: Hyprland.monitorFor(modelData)?.lastIpcObject?.specialWorkspace?.name ?? ""
    readonly property bool active: special !== ""
    readonly property string key: special.replace(/^special:/, "")

    readonly property var marks: ({
        pad: { icon: "forum", color: Theme.accent }
    })
    readonly property var mark: marks[key] ?? ({ icon: "layers", color: Theme.t2 })

    anchors { top: true; left: true }
    implicitWidth: 120
    implicitHeight: 80
    color: "transparent"
    visible: (active || tab.depth > 0.5) && !NotchState.hidden

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-special-ear"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        x: -1
        y: -1
        width: 1
        height: 1
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name !== "activespecialv2")
                return;
            const args = event.parse(3);
            if (args[2] !== win.monName)
                return;
            win.special = args[1];
        }
    }

    EdgeTab {
        id: tab
        edge: "top"
        corner: "left"
        window: win
        anchors.top: parent.top
        anchors.left: parent.left

        pinned: win.active
        openLength: 64
        openDepth: NotchState.collapsedH
        tint: NotchState.floating ? Theme.notchGlass : "#000000"

        content: Icon {
            anchors.centerIn: parent
            size: 18
            filled: true
            text: win.mark.icon
            color: win.mark.color
            opacity: tab.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
