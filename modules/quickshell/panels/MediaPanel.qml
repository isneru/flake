import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import "root:/singletons"
import "root:/components"

RowLayout {
    id: root
    spacing: 16

    readonly property MprisPlayer player: NotchState.mediaPlayer

    property real pos: 0
    property bool scrubbing: false
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.scrubbing) root.pos = root.player?.position ?? 0
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

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 22

            Item {
                Layout.preferredWidth: 118
                Layout.preferredHeight: 118

                Rectangle {
                    id: art
                    anchors.fill: parent
                    radius: 14
                    color: Theme.s2
                    clip: true

                    Stripes {
                        anchors.fill: parent
                        radius: 14
                        strength: 0.14
                        visible: cover.status !== Image.Ready
                    }
                    Image {
                        id: cover
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: cover
                        source: cover
                        visible: cover.status === Image.Ready
                        maskEnabled: true
                        maskSource: artMask
                        maskThresholdMin: 0.5
                    }
                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: 14
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "NOW PLAYING - " + (root.player?.identity ?? "NOTHING").toUpperCase()
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 0.6
                    color: Theme.accent
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.player?.trackTitle || "Nothing playing"
                    font.family: Theme.ui
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    color: Theme.t1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    readonly property string artist: root.player?.trackArtist ?? ""
                    readonly property string album: root.player?.trackAlbum ?? ""
                    text: album ? artist + " — " + album : artist
                    font.family: Theme.ui
                    font.pixelSize: 13
                    color: Theme.t2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Item { Layout.fillHeight: true }
            }
        }

        Item { Layout.preferredHeight: 22; Layout.fillHeight: false }

        HSlider {
            Layout.fillWidth: true
            trackHeight: 5
            enabled: root.player?.canSeek ?? false
            value: {
                const len = root.player?.length ?? 0;
                return len > 0 ? Math.round(100 * root.pos / len) : 0;
            }
            onMoved: v => {
                const len = root.player?.length ?? 0;
                if (len > 0) {
                    root.pos = len * v / 100;
                    if (root.player)
                        root.player.position = root.pos;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Text {
                text: root.clock(root.pos)
                font.family: Theme.mono
                font.pixelSize: 12
                color: Theme.t2
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.clock(root.player?.length ?? 0)
                font.family: Theme.mono
                font.pixelSize: 12
                color: Theme.t2
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            Layout.fillHeight: false
            spacing: 22

            Icon {
                size: 21
                text: "shuffle"
                filled: root.player?.shuffle ?? false
                color: (root.player?.shuffle ?? false) ? Theme.accent : Theme.t2
                opacity: (root.player?.shuffleSupported ?? false) ? 1 : 0.35
                TapHandler {
                    enabled: root.player?.shuffleSupported ?? false
                    onTapped: root.player.shuffle = !root.player.shuffle
                }
            }
            Icon {
                size: 29
                text: "skip_previous"
                filled: true
                color: Theme.t1
                opacity: (root.player?.canGoPrevious ?? false) ? 1 : 0.35
                TapHandler {
                    enabled: root.player?.canGoPrevious ?? false
                    onTapped: root.player.previous()
                }
            }
            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 26
                color: "#ffffff"
                opacity: (root.player?.canTogglePlaying ?? false) ? 1 : 0.35
                Icon {
                    anchors.centerIn: parent
                    size: 24
                    filled: true
                    text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                    color: Theme.fgOnAccent
                }
                TapHandler {
                    enabled: root.player?.canTogglePlaying ?? false
                    onTapped: root.player.togglePlaying()
                }
            }
            Icon {
                size: 29
                text: "skip_next"
                filled: true
                color: Theme.t1
                opacity: (root.player?.canGoNext ?? false) ? 1 : 0.35
                TapHandler {
                    enabled: root.player?.canGoNext ?? false
                    onTapped: root.player.next()
                }
            }
            Icon {
                readonly property int loop: root.player?.loopState ?? MprisLoopState.None
                size: 21
                text: loop === MprisLoopState.Track ? "repeat_one" : "repeat"
                filled: loop !== MprisLoopState.None
                color: loop !== MprisLoopState.None ? Theme.accent : Theme.t2
                opacity: (root.player?.loopSupported ?? false) ? 1 : 0.35
                TapHandler {
                    enabled: root.player?.loopSupported ?? false
                    onTapped: {
                        const next = ({});
                        next[MprisLoopState.None] = MprisLoopState.Playlist;
                        next[MprisLoopState.Playlist] = MprisLoopState.Track;
                        next[MprisLoopState.Track] = MprisLoopState.None;
                        root.player.loopState = next[root.player.loopState];
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 18
            Layout.preferredHeight: 52
            radius: 13
            color: outHover.hovered ? Theme.s3 : Theme.s1
            Behavior on color { ColorAnimation { duration: 160 } }
            HoverHandler { id: outHover }
            TapHandler { onTapped: NotchState.open("audio") }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Icon { size: 21; filled: true; text: "headphones"; color: Theme.accent }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: Audio.sinkName || "No output"
                        font.family: Theme.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.t1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "pipewire"
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.t3
                    }
                }
                Icon { size: 17; text: "chevron_right"; color: Theme.t4 }
            }
        }

        Item { Layout.fillHeight: true }
    }

    ColumnLayout {
        Layout.preferredWidth: 250
        Layout.fillWidth: false
        Layout.fillHeight: true
        spacing: 10

        Text {
            text: "SOURCES"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: Theme.s1

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: NotchState.mediaPlayers.length === 0
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 26
                    text: "queue_music"
                    color: Theme.t4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No players"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    color: Theme.t3
                }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 4

                Repeater {
                    model: NotchState.mediaPlayers

                    delegate: Rectangle {
                        id: src
                        required property var modelData
                        readonly property bool active: NotchState.mediaPlayer === modelData
                        readonly property bool pinned: NotchState.mediaPin !== "" && NotchState.playerId(modelData) === NotchState.mediaPin

                        width: parent.width
                        height: 42
                        radius: 11
                        color: src.active ? Theme.s3 : (srcHover.hovered ? Theme.s2 : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        HoverHandler { id: srcHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: NotchState.pinMedia(src.modelData)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 9

                            Icon {
                                size: 17
                                filled: src.modelData.isPlaying
                                text: src.modelData.isPlaying ? "graphic_eq" : "music_note"
                                color: src.modelData.isPlaying ? Theme.accent : Theme.t3
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: src.modelData.identity || src.modelData.desktopEntry || "Player"
                                    font.family: Theme.ui
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: Theme.t1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: text !== ""
                                    text: src.modelData.trackTitle ?? ""
                                    font.family: Theme.ui
                                    font.pixelSize: 10
                                    color: Theme.t3
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            Icon {
                                visible: src.pinned || srcHover.hovered
                                size: 15
                                filled: src.pinned
                                text: "push_pin"
                                color: src.pinned ? Theme.accent : Theme.t4
                            }
                        }
                    }
                }
            }
        }
    }
}
