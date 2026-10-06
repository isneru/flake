import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/singletons"
import "root:/components"

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property int sliderH: 150

    anchors { right: true }
    implicitWidth: 200
    implicitHeight: 300
    color: "transparent"
    visible: !NotchState.hidden && !Lock.active

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-sliders"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: tab }

    EdgeTab {
        id: tab
        edge: "right"
        window: win
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        openDepth: 104
        openLength: win.sliderH + 49

        content: Row {
            anchors.centerIn: parent
            spacing: 10
            opacity: tab.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: [
                    { icon: Audio.muted ? "volume_off" : "volume_up", key: "volume", c: Theme.accent, set: v => NotchState.setVolume(v) },
                    { icon: "brightness_6", key: "brightness", c: Qt.rgba(1, 1, 1, 0.85), set: v => NotchState.setBrightness(v) },
                    { icon: Audio.micMuted ? "mic_off" : "mic", key: "micGain", c: Theme.success, set: v => NotchState.setMicGain(v) }
                ]

                delegate: Column {
                    id: col
                    required property var modelData
                    spacing: 9

                    VSlider {
                        width: 20
                        height: win.sliderH
                        enabled: tab.open
                        value: NotchState[col.modelData.key]
                        fill: col.modelData.c
                        onMoved: v => col.modelData.set(v)
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 16
                        text: col.modelData.icon
                        color: Theme.t2
                    }
                }
            }
        }
    }
}
