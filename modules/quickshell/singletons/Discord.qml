pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var state: ({})

    readonly property bool running: state.running === true
    readonly property bool call: running && state.call === true
    readonly property bool speaking: call && state.speaking === true

    function apply(txt) {
        try {
            state = JSON.parse(txt);
        } catch (e) {}
    }

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/discord.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: root.state = {}
    }
}
