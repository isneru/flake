import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12
    readonly property var player: NotchState.mediaPlayer

    Component.onCompleted: Sensors.watchers++
    Component.onDestruction: Sensors.watchers--

    property real pos: 0
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = root.player?.position ?? 0
    }
    Connections {
        target: root.player
        function onTrackTitleChanged() { root.pos = 0; }
    }

    function clock(s) {
        if (!(s > 0))
            return "0:00";
        return Math.floor(s / 60) + ":" + String(Math.floor(s % 60)).padStart(2, "0");
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 196
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 0
            Layout.horizontalStretchFactor: 115
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Theme.s1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.leftMargin: 18
                spacing: 0

                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: Theme.mono
                    font.pixelSize: 52
                    font.weight: Font.Light
                    font.letterSpacing: -1
                    color: Theme.t1
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    font.family: Theme.ui
                    font.pixelSize: 13
                    color: Theme.alpha(Theme.t1, 0.5)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    visible: !!Agenda.current
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: Agenda.headline(Agenda.current)
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                        color: Agenda.current?.color ?? Theme.accent
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Agenda.current?.title ?? ""
                        font.family: Theme.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.t1
                        elide: Text.ElideRight
                    }
                }
                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 14
                }
                Row {
                    Layout.fillHeight: false
                    spacing: 16
                    Text {
                        text: "up " + Sensors.uptime
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.t3
                    }
                    Text {
                        text: "hyprland " + Sensors.hyprland
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.t3
                    }
                    Text {
                        text: "kernel " + Sensors.kernel
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.t3
                    }
                }
            }
        }

        GridLayout {
            Layout.preferredWidth: 0
            Layout.horizontalStretchFactor: 100
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            Tile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: NotchState.wired ? "lan" : "wifi"
                label: "Wi-Fi"
                sub: NotchState.wired
                    ? NotchState.networkName
                    : (NotchState.toggles.wifi ? (NotchState.ssid || "not connected") : "off")
                on: NotchState.toggles.wifi
                onClicked: NotchState.toggle("wifi")
            }
            Tile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "bluetooth"
                label: "Bluetooth"
                sub: NotchState.toggles.bt ? (NotchState.btConnected + " connected") : "off"
                on: NotchState.toggles.bt
                onClicked: NotchState.toggle("bt")
            }
            Tile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "do_not_disturb_on"
                label: "Do not disturb"
                sub: NotchState.toggles.dnd ? "on" : "off"
                on: NotchState.toggles.dnd
                activeColor: Theme.warning
                onClicked: NotchState.toggle("dnd")
            }
            Tile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "nightlight"
                label: "Night light"
                sub: NotchState.toggles.night ? NightLight.temperature + " K" : "off"
                on: NotchState.toggles.night
                activeColor: Theme.warning
                scrollable: NotchState.toggles.night
                onClicked: NotchState.toggle("night")
                onScrolled: steps => NightLight.step(steps)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 74
        radius: 16
        color: Theme.s1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 13
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 9

            RowLayout {
                spacing: 12
                Icon { size: 19; text: Audio.muted ? "volume_off" : "volume_up"; color: Theme.alpha(Theme.t1, 0.75) }
                HSlider {
                    Layout.fillWidth: true
                    trackHeight: 8
                    value: NotchState.volume
                    onMoved: v => NotchState.setVolume(v)
                }
                Text {
                    text: NotchState.volume + "%"
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 34
                    font.family: Theme.mono
                    font.pixelSize: 12
                    color: Theme.t2
                }
            }
            RowLayout {
                spacing: 12
                Icon { size: 19; text: "brightness_6"; color: Theme.alpha(Theme.t1, 0.75) }
                HSlider {
                    Layout.fillWidth: true
                    trackHeight: 8
                    fill: Qt.rgba(1, 1, 1, 0.85)
                    value: NotchState.brightness
                    onMoved: v => NotchState.setBrightness(v)
                }
                Text {
                    text: NotchState.brightness + "%"
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 34
                    font.family: Theme.mono
                    font.pixelSize: 12
                    color: Theme.t2
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 0
            Layout.horizontalStretchFactor: 115
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: hover.hovered ? Theme.s3 : Theme.s1
            Behavior on color { ColorAnimation { duration: 160 } }
            HoverHandler { id: hover }
            TapHandler { onTapped: NotchState.open("media") }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 13

                Item {
                    Layout.preferredWidth: height
                    Layout.fillHeight: true

                    Stripes {
                        anchors.fill: parent
                        radius: 12
                        strength: 0.14
                        visible: miniArt.status !== Image.Ready
                    }
                    Image {
                        id: miniArt
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: miniArt
                        source: miniArt
                        visible: miniArt.status === Image.Ready
                        maskEnabled: true
                        maskSource: miniArtMask
                        maskThresholdMin: 0.5
                    }
                    Rectangle {
                        id: miniArtMask
                        anchors.fill: parent
                        radius: 12
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Text {
                        text: root.player ? "NOW PLAYING - " + (root.player.identity ?? "").toUpperCase() : "MEDIA"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.letterSpacing: 0.85
                        color: root.player ? Theme.accent : Theme.t4
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.bottomMargin: 3
                    }
                    Text {
                        text: root.player?.trackTitle || "Nothing playing"
                        font.family: Theme.ui
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Theme.t1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.player?.trackArtist || (root.player ? "unknown artist" : "nothing is using MPRIS")
                        font.family: Theme.ui
                        font.pixelSize: 12
                        color: Theme.alpha(Theme.t1, 0.5)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: playHover.hovered ? Theme.s4 : Theme.alpha(Theme.t1, 0.1)
                            Behavior on color { ColorAnimation { duration: 140 } }
                            opacity: (root.player?.canTogglePlaying ?? false) ? 1 : 0.4
                            HoverHandler { id: playHover }
                            Icon {
                                anchors.centerIn: parent
                                size: 19
                                filled: true
                                text: root.player?.isPlaying ? "pause" : "play_arrow"
                            }
                            TapHandler {
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                enabled: root.player?.canTogglePlaying ?? false
                                onTapped: root.player.togglePlaying()
                            }
                        }

                        Rectangle {
                            visible: (root.player?.length ?? 0) > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 3
                            radius: 1.5
                            color: Theme.track

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, root.pos / (root.player?.length || 1)))
                                height: parent.height
                                radius: parent.radius
                                color: Theme.accent
                                Behavior on width { NumberAnimation { duration: 900 } }
                            }
                        }
                        Item { Layout.fillWidth: true; visible: (root.player?.length ?? 0) <= 0 }
                        Text {
                            visible: (root.player?.length ?? 0) > 0
                            text: root.clock(root.pos) + " / " + root.clock(root.player?.length ?? 0)
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.t4
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 0
            Layout.horizontalStretchFactor: 100
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Theme.s1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8

                Repeater {
                    model: [
                        { k: "cpu", unit: "%", c: Theme.accent },
                        { k: "ram", unit: "%", c: Theme.success },
                        { k: "temp", unit: "°C", c: Theme.warning }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        readonly property int value: Sensors[modelData.k]
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: modelData.k
                            Layout.preferredWidth: 30
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.alpha(Theme.t1, 0.45)
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 5
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.11)
                            Rectangle {
                                width: parent.width * Math.min(100, parent.parent.value) / 100
                                height: parent.height
                                radius: parent.radius
                                color: modelData.c
                                Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.Bezier; easing.bezierCurve: [0.3, 0.9, 0.3, 1, 1, 1] } }
                            }
                        }
                        Text {
                            text: parent.value + modelData.unit
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.t2
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: date = new Date()
    }
}
