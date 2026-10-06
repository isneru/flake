import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/panels"

Item {
    id: root

    readonly property var titles: ({
        home: ["Control Notch", "everything at a glance"],
        media: ["Now playing", "MPRIS"],
        control: ["Control centre", "connectivity and toggles"],
        notif: ["Notifications", "notification server"],
        cal: ["Calendar", "agenda"],
        spaces: ["Workspaces", "Hyprland"],
        tools: ["Tools", "everything else you might need"],
        keys: ["Keybindings", "hyprland - notch"],
        launcher: ["Launcher", "apps - settings - files"],
        calc: ["Calculator", "qalc - ↵ copies the result"],
        clip: ["Clipboard", "cliphist history"],
        shelf: ["Files shelf", "dropped files, held by path"],
        send: ["LocalSend", "files over the LAN"],
        timer: ["Timer", "countdown - pomodoro"],
        weather: ["Weather", "open-meteo - pinned location"],
        auth: ["Authorize", "polkit - askpass"],
        share: ["Share your screen", "xdg-desktop-portal - screencast"],
        net: ["Network", "rates - latency - DNS"],
        wifi: ["Network", "NetworkManager - nearby"],
        qr: ["QR scanner", "zbar - decoded in memory"],
        wall: ["Appearance", "wallpaper - theme-set - awww"],
        theme: ["Appearance", "palettes - theme-set"],
        monitor: ["System monitor", "live sensors"],
        display: ["Displays", "hyprctl monitors"],
        power: ["Battery & power", "upower - power-profiles-daemon"],
        audio: ["Audio routing", "PipeWire - WirePlumber"],
        bt: ["Bluetooth", "bluez"],
        shell: ["Appearance", "notch shape - motion - layout"],
        tray: ["Tray", "StatusNotifier hosts"]
    })
    readonly property var t: NotchState.panel === "pick"
        ? [Picks.source?.title ?? "Pick", Picks.source?.desc ?? ""]
        : (titles[NotchState.panel] ?? titles.home)

    readonly property var dock: [
        { key: "home", icon: "space_dashboard", label: "Home" },
        { key: "media", icon: "music_note", label: "Media" },
        { key: "control", icon: "tune", label: "Control" },
        { key: "notif", icon: "notifications", label: "Alerts" },
        { key: "cal", icon: "calendar_month", label: "Calendar" },
        { key: "spaces", icon: "grid_view", label: "Spaces" },
        { key: "tools", icon: "widgets", label: "Tools" }
    ]
    readonly property var rootOf: ({
        clip: "tools", shelf: "tools", send: "tools", timer: "tools", weather: "tools", wall: "tools", theme: "tools",
        monitor: "tools", display: "tools", audio: "tools",
        shell: "tools", net: "tools", qr: "tools", wifi: "tools", bt: "tools", keys: "tools"
    })
    readonly property string activeRoot: rootOf[NotchState.panel] ?? NotchState.panel

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.preferredHeight: 54
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 20
            spacing: 12

            RoundButton2 {
                visible: NotchState.navStack.length > 0 && !NotchState.modal
                icon: "arrow_back"
                onTapped: NotchState.back()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: root.t[0]
                    font.family: Theme.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: Theme.t1
                }
                Text {
                    text: root.t[1]
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.t3
                }
            }

            Item { Layout.fillWidth: true }

            RoundButton2 { visible: !NotchState.modal; icon: "search"; onTapped: NotchState.open("launcher") }
            RoundButton2 { visible: !NotchState.modal; icon: "power_settings_new"; onTapped: NotchState.open("power") }
            RoundButton2 { visible: !NotchState.modal; icon: "close"; onTapped: NotchState.close() }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            Loader {
                id: body
                anchors.fill: parent
                source: {
                    switch (NotchState.panel) {
                    case "home": return "root:/panels/HomePanel.qml";
                    case "media": return "root:/panels/MediaPanel.qml";
                    case "control": return "root:/panels/ControlPanel.qml";
                    case "notif": return "root:/panels/NotifPanel.qml";
                    case "cal": return "root:/panels/CalPanel.qml";
                    case "spaces": return "root:/panels/SpacesPanel.qml";
                    case "audio": return "root:/panels/AudioPanel.qml";
                    case "wifi": return "root:/panels/WifiPanel.qml";
                    case "bt": return "root:/panels/BtPanel.qml";
                    case "monitor": return "root:/panels/MonitorPanel.qml";
                    case "display": return "root:/panels/DisplayPanel.qml";
                    case "power": return "root:/panels/PowerPanel.qml";
                    case "launcher":
                    case "calc": return "root:/panels/LauncherPanel.qml";
                    case "pick": return "root:/panels/PickPanel.qml";
                    case "wall": return "root:/panels/WallPanel.qml";
                    case "theme": return "root:/panels/ThemePanel.qml";
                    case "clip": return "root:/panels/ClipPanel.qml";
                    case "shelf": return "root:/panels/ShelfPanel.qml";
                    case "send": return "root:/panels/SendPanel.qml";
                    case "timer": return "root:/panels/TimerPanel.qml";
                    case "weather": return "root:/panels/WeatherPanel.qml";
                    case "auth": return "root:/panels/AuthPanel.qml";
                    case "share": return "root:/panels/SharePanel.qml";
                    case "net": return "root:/panels/NetPanel.qml";
                    case "qr": return "root:/panels/QrPanel.qml";
                    case "shell": return "root:/panels/AppearancePanel.qml";
                    case "keys": return "root:/panels/KeysPanel.qml";
                    case "tray": return "root:/panels/TrayPanel.qml";
                    case "tools": return "root:/panels/ToolsPanel.qml";
                    default: return "root:/panels/TodoPanel.qml";
                    }
                }
                onLoaded: { item.opacity = 0; fade.start(); }
                NumberAnimation {
                    id: fade
                    target: body.item
                    property: "opacity"
                    to: 1
                    duration: 260
                    easing.type: Easing.Bezier
                    easing.bezierCurve: [0.2, 0.9, 0.2, 1, 1, 1]
                }
            }
        }

        Row {
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignHCenter
            spacing: 5

            enabled: !NotchState.modal
            opacity: NotchState.modal ? 0.35 : 1
            Behavior on opacity { NumberAnimation { duration: 240 } }

            Repeater {
                model: root.dock
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.activeRoot === modelData.key
                    anchors.verticalCenter: parent.verticalCenter
                    width: 54
                    height: 44
                    radius: 13
                    color: active ? Theme.s4 : "transparent"
                    Behavior on color { ColorAnimation { duration: 240 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 20
                            filled: parent.parent.active
                            text: parent.parent.modelData.icon
                            color: parent.parent.active ? Theme.t1 : Theme.alpha(Theme.t1, 0.5)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.label
                            font.family: Theme.ui
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: parent.parent.active ? Theme.t1 : Theme.alpha(Theme.t1, 0.5)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotchState.open(parent.modelData.key)
                    }
                }
            }
        }
    }

    opacity: 0
    y: 10
    Component.onCompleted: { opacity = 1; y = 0; }
    Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0.9, 0.2, 1, 1, 1] } }
    Behavior on y { NumberAnimation { duration: 420 } }
}
