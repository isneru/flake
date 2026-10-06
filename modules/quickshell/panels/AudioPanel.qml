import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "root:/singletons"
import "root:/components"

RowLayout {
    id: root
    spacing: 16

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio).sort((a, b) => root.serialOf(a) - root.serialOf(b))
    readonly property var micStreams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio).sort((a, b) => root.serialOf(a) - root.serialOf(b))

    function serialOf(n) {
        return parseInt(n?.properties?.["object.serial"] ?? "0") || 0;
    }

    readonly property var devices: {
        const all = Pipewire.nodes.values.filter(n => !n.isStream && n.audio);
        return all.filter(n => n.isSink).concat(all.filter(n => !n.isSink));
    }

    readonly property PwNode virtualSource: {
        const d = Pipewire.defaultAudioSource;
        return d && !d.audio ? d : null;
    }

    readonly property real micLevel: {
        const p = micPeak.peak;
        return p > 0 ? Math.pow(Math.min(1, p), 0.5) : 0;
    }

    PwObjectTracker {
        objects: root.streams.concat(root.micStreams).concat(root.devices)
    }

    PwNodePeakMonitor {
        id: micPeak
        node: Audio.micNode
        enabled: true
    }

    function label(n) {
        return Apps.nameFor(n);
    }

    function pct(n) {
        return Math.round((n?.audio?.volume ?? 0) * 100);
    }

    function muteIcon(n) {
        if (n.isSink)
            return n.audio.muted ? "volume_off" : "volume_up";
        return n.audio.muted ? "mic_off" : "mic";
    }

    function isDefaultDevice(n) {
        if (n.isSink)
            return Pipewire.defaultAudioSink?.id === n.id;
        const d = Pipewire.defaultAudioSource;
        return (d?.audio ? d.id : Audio.micNode?.id) === n.id;
    }

    Component {
        id: streamRow

        Rectangle {
            id: stream
            required property var modelData
            width: ListView.view.width
            height: 62
            radius: Theme.rCard
            color: Theme.s1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 9
                    color: Theme.s2
                    Icon {
                        anchors.centerIn: parent
                        size: 16
                        filled: true
                        text: stream.modelData.isSink ? "graphic_eq" : "mic"
                        color: stream.modelData.isSink ? Theme.accent : Theme.success
                    }
                }
                Text {
                    Layout.preferredWidth: 74
                    text: root.label(stream.modelData)
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.t1
                    elide: Text.ElideRight
                }
                HSlider {
                    Layout.fillWidth: true
                    trackHeight: 6
                    fill: stream.modelData.isSink ? Theme.accent : Theme.success
                    value: root.pct(stream.modelData)
                    onMoved: v => stream.modelData.audio.volume = v / 100
                }
                Text {
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignRight
                    text: root.pct(stream.modelData)
                    font.family: Theme.mono
                    font.pixelSize: 12
                    color: Theme.t2
                }
                Icon {
                    size: 18
                    filled: true
                    text: root.muteIcon(stream.modelData)
                    color: stream.modelData.audio.muted ? Theme.error : Theme.t2
                    TapHandler { onTapped: stream.modelData.audio.muted = !stream.modelData.audio.muted }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        Text {
            text: "PER-APP VOLUME - PIPEWIRE"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.streams.length > 0
            clip: true
            spacing: 10
            model: root.streams
            delegate: streamRow
            boundsBehavior: Flickable.StopAtBounds
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.streams.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 28
                    text: "music_off"
                    color: Theme.t4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing playing audio"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    color: Theme.t3
                }
            }
        }

        Text {
            visible: root.micStreams.length > 0
            text: "RECORDING"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(2, root.micStreams.length) * 72 - 10
            visible: root.micStreams.length > 0
            clip: true
            spacing: 10
            model: root.micStreams
            delegate: streamRow
            boundsBehavior: Flickable.StopAtBounds
        }
    }

    ColumnLayout {
        Layout.preferredWidth: 262
        Layout.fillWidth: false
        Layout.fillHeight: true
        spacing: 10

        Text {
            text: "DEVICES"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            radius: Theme.rCard
            color: Theme.s1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 11

                Icon {
                    size: 19
                    filled: true
                    text: Audio.micMuted ? "mic_off" : "mic"
                    color: Audio.micMuted ? Theme.error : Theme.success
                    TapHandler { onTapped: Audio.toggleMicMute() }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: Audio.sourceName || "No input"
                        font.family: Theme.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.t1
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        radius: 2
                        color: Theme.track

                        Rectangle {
                            width: parent.width * root.micLevel
                            height: parent.height
                            radius: parent.radius
                            color: Audio.micMuted ? Theme.t4 : Theme.success
                            Behavior on width { NumberAnimation { duration: 90 } }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.virtualSource !== null
                        text: "via " + (root.virtualSource?.description ?? root.virtualSource?.name ?? "")
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.t3
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.devices
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: dev
                required property var modelData
                readonly property bool isDefault: root.isDefaultDevice(dev.modelData)

                width: ListView.view.width
                height: 76
                radius: 13
                color: dev.isDefault ? Theme.s3 : (devHover.hovered ? Theme.s2 : Theme.s1)
                Behavior on color { ColorAnimation { duration: 160 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    anchors.topMargin: 9
                    anchors.bottomMargin: 9
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 11

                        HoverHandler { id: devHover }
                        TapHandler {
                            onTapped: {
                                if (dev.modelData.isSink)
                                    Pipewire.preferredDefaultAudioSink = dev.modelData;
                                else
                                    Pipewire.preferredDefaultAudioSource = dev.modelData;
                            }
                        }

                        Icon {
                            size: 19
                            filled: true
                            text: dev.modelData.isSink ? "speaker" : "mic"
                            color: dev.isDefault ? Theme.accent : Theme.t2
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: dev.modelData.description || dev.modelData.name
                                font.family: Theme.ui
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.t1
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: dev.modelData.name
                                font.family: Theme.mono
                                font.pixelSize: 10
                                color: Theme.t3
                                elide: Text.ElideRight
                            }
                        }
                        Icon {
                            size: 17
                            text: "check"
                            color: Theme.t1
                            visible: dev.isDefault
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        spacing: 10

                        HSlider {
                            Layout.fillWidth: true
                            trackHeight: 5
                            fill: dev.modelData.isSink ? Theme.accent : Theme.success
                            value: root.pct(dev.modelData)
                            onMoved: v => dev.modelData.audio.volume = v / 100
                        }
                        Text {
                            Layout.preferredWidth: 26
                            horizontalAlignment: Text.AlignRight
                            text: root.pct(dev.modelData)
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.t2
                        }
                        Icon {
                            size: 16
                            filled: true
                            text: root.muteIcon(dev.modelData)
                            color: dev.modelData.audio.muted ? Theme.error : Theme.t2
                            TapHandler { onTapped: dev.modelData.audio.muted = !dev.modelData.audio.muted }
                        }
                    }
                }
            }
        }
    }
}
