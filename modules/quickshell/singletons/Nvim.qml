pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property var appIds: ["kitty", "yazi", "filepicker"]
    readonly property var focused: Hyprland.activeToplevel
    readonly property bool watching: root.appIds.includes(root.focused?.wayland?.appId ?? "")
    readonly property int pid: root.watching ? (root.focused?.lastIpcObject?.pid ?? 0) : 0
    readonly property string title: root.watching ? (root.focused?.title ?? "") : ""

    property var state: ({})
    property int retries: 0

    readonly property bool running: root.pid > 0 && root.state.server !== undefined
    readonly property string mode: state.mode ?? "NORMAL"
    readonly property var row: state.row ?? null

    readonly property color modeColor: {
        switch (root.mode) {
        case "INSERT":
            return Theme.success;
        case "VISUAL":
        case "V-LINE":
        case "V-BLOCK":
        case "SELECT":
        case "S-LINE":
        case "S-BLOCK":
            return Theme.ansiBrightMagenta;
        case "REPLACE":
        case "V-REPLACE":
            return Theme.error;
        case "COMMAND":
        case "EX":
            return Theme.warning;
        case "TERMINAL":
        case "SHELL":
            return Theme.info;
        }
        return Theme.accent;
    }

    function rich(max) {
        const r = root.row;
        if (!r)
            return "";
        const cells = [];
        for (const span of r.spans)
            for (const c of Array.from(span.text))
                cells.push([c, span]);
        const cur = r.cursor ?? -1;
        if (cur >= cells.length)
            cells.push([" ", {}]);
        let start = 0;
        let end = cells.length;
        if (cells.length > max) {
            if (cur >= 0) {
                const room = max - 1;
                start = Math.max(0, Math.min(cur - room + 1, cells.length - room));
                end = start + room;
                if (start > 0 && end < cells.length) {
                    if (cur >= end - 1)
                        start++;
                    else
                        end--;
                }
            } else {
                end = max - 1;
            }
        }
        const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
        const piece = (t, s, cursor) => {
            let fg = s.fg ?? Theme.fg;
            let bg = s.bg ?? null;
            if (s.reverse)
                [fg, bg] = [bg ?? Theme.bg, fg];
            if (cursor)
                [fg, bg] = [Theme.bg, Theme.accent];
            const deco = [s.underline || s.undercurl ? "underline" : "", s.strikethrough ? "line-through" : ""].filter(d => d).join(" ");
            const style = `color:${fg};` + (bg ? `background-color:${bg};` : "") + (s.bold ? "font-weight:bold;" : "") + (s.italic ? "font-style:italic;" : "") + (deco ? `text-decoration:${deco};` : "");
            return `<span style="${style}">${esc(t)}</span>`;
        };
        let out = start > 0 ? piece("…", {}, false) : "";
        let run = "";
        let runSpan = null;
        for (let i = start; i < end; i++) {
            const [c, s] = cells[i];
            if (i === cur) {
                if (run)
                    out += piece(run, runSpan, false);
                out += piece(c, s, true);
                run = "";
                runSpan = null;
            } else if (s === runSpan) {
                run += c;
            } else {
                if (run)
                    out += piece(run, runSpan, false);
                run = c;
                runSpan = s;
            }
        }
        if (run)
            out += piece(run, runSpan, false);
        if (end < cells.length)
            out += piece("…", {}, false);
        return out;
    }

    onFocusedChanged: {
        if (root.watching)
            Hyprland.refreshToplevels();
    }
    onWatchingChanged: {
        if (root.watching)
            Hyprland.refreshToplevels();
    }
    onPidChanged: {
        root.state = {};
        root.retries = 0;
    }
    onTitleChanged: {
        if (!root.running)
            root.retries = 0;
    }

    function click() {
        if (!root.running)
            return;
        Quickshell.execDetached(["nvim", "--server", root.state.server, "--remote-expr", `luaeval('require("neru.bar").click()')`]);
    }

    function send(keys) {
        if (!root.running)
            return;
        Quickshell.execDetached(["nvim", "--server", root.state.server, "--remote-send", keys]);
    }

    LazyLoader {
        id: loader
        active: root.pid > 0
        component: FileView {
            path: root.pid > 0 ? `${Quickshell.env("XDG_RUNTIME_DIR")}/nvim-bar-${root.pid}.json` : ""
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: root.apply(text())
            onLoadFailed: root.state = {}
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.pid > 0 && !root.running && root.retries < 8
        onTriggered: {
            root.retries++;
            loader.active = false;
            loader.active = Qt.binding(() => root.pid > 0);
        }
    }

    function apply(txt) {
        try {
            root.state = JSON.parse(txt);
        } catch (e) {}
    }
}
