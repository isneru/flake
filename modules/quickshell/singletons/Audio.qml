pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    property string eeInputDevice: ""

    readonly property PwNode micNode: {
        if (source?.audio)
            return source;
        const sources = Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink && n.audio);
        return sources.find(n => n.name === root.eeInputDevice)
            ?? sources.find(n => (n.name ?? "").startsWith("alsa_input."))
            ?? sources[0]
            ?? null;
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/easyeffects/db/easyeffectsrc`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = /^inputDevice=(.*)$/m.exec(text());
            root.eeInputDevice = m ? m[1].trim() : "";
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source, root.micNode]
    }

    readonly property int volume: Math.round((sink?.audio.volume ?? 0) * 100)
    readonly property bool muted: sink?.audio.muted ?? false
    readonly property int micGain: Math.round((micNode?.audio?.volume ?? 0) * 100)
    readonly property bool micMuted: micNode?.audio?.muted ?? false
    readonly property string sinkName: sink?.description ?? sink?.nickname ?? ""
    readonly property string sourceName: micNode?.description ?? micNode?.nickname ?? micNode?.name ?? ""

    function setVolume(v) {
        if (sink)
            sink.audio.volume = Math.max(0, Math.min(100, v)) / 100;
    }
    function setMicGain(v) {
        if (micNode?.audio)
            micNode.audio.volume = Math.max(0, Math.min(100, v)) / 100;
    }
    function toggleMute() {
        if (sink)
            sink.audio.muted = !sink.audio.muted;
    }
    function toggleMicMute() {
        if (micNode?.audio)
            micNode.audio.muted = !micNode.audio.muted;
    }
}
