pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string appId: "org.qutebrowser.qutebrowser"

    property var state: ({})
    property var queue: []

    readonly property bool running: state.running === true
    readonly property string mode: state.mode ?? "normal"
    readonly property string modeCode: {
        switch (mode) {
        case "normal":
            return "NOR";
        case "insert":
            return "INS";
        case "passthrough":
            return "PAS";
        case "command":
            return "CMD";
        case "hint":
            return "HNT";
        case "caret":
            return state.selection ? "SEL" : "CAR";
        case "prompt":
        case "yesno":
            return "PRM";
        case "set_mark":
        case "jump_mark":
            return "MRK";
        case "record_macro":
        case "run_macro":
            return "REG";
        }
        return mode.slice(0, 3).toUpperCase();
    }
    readonly property string url: state.url ?? ""
    readonly property string keys: state.keys ?? ""
    readonly property var match: state.match ?? null
    readonly property var scroll: state.scroll ?? null
    readonly property bool loading: state.loading === true

    readonly property string scrollLabel: {
        if (scroll === null)
            return "[???]";
        if (scroll <= 0)
            return "[top]";
        if (scroll >= 100)
            return "[bot]";
        return `[${String(scroll).padStart(2, "0")}%]`;
    }

    readonly property color modeColor: {
        switch (mode) {
        case "insert":
            return Theme.ansiGreen;
        case "passthrough":
            return Theme.info;
        case "caret":
            return state.selection ? Theme.accent : Theme.ansiYellow;
        case "hint":
            return Theme.ansiYellow;
        }
        return Theme.accent;
    }

    readonly property color urlColor: {
        switch (state.urlType) {
        case "success_https":
            return Theme.ansiGreen;
        case "success":
        case "warn":
            return Theme.ansiYellow;
        case "error":
            return Theme.ansiRed;
        case "hover":
            return Theme.ansiBlue;
        }
        return Theme.fg;
    }

    function elide(text, max) {
        return text.length > max ? text.slice(0, max - 1) + "…" : text;
    }

    function send(command) {
        if (!state.socket)
            return;
        queue = queue.concat([command]);
        if (sock.connected)
            drain();
        else
            sock.connected = true;
    }

    function drain() {
        for (const command of queue)
            sock.write(JSON.stringify({
                args: [command],
                target_arg: null,
                protocol_version: 1
            }) + "\n");
        queue = [];
        sock.flush();
        sock.connected = false;
    }

    Socket {
        id: sock
        path: root.state.socket ?? ""
        onConnectionStateChanged: {
            if (connected)
                root.drain();
        }
        onError: root.queue = []
    }

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/qute.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: root.state = {}
    }

    function apply(txt) {
        try {
            state = JSON.parse(txt);
        } catch (e) {}
    }
}
