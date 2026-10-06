pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/pictures/wallpapers"
    readonly property string previewDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/theme-engine/wallpaper-previews"

    property var papers: []
    property var palettes: ({})
    readonly property var themes: Object.keys(palettes)
    property string source: ""
    property bool recolor: true
    property string previewTheme: ""

    readonly property bool picked: source !== ""

    Process {
        running: true
        command: ["sh", "-c", "ls -1 " + root.dir + "/*.{png,jpg,jpeg,webp} 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.papers = text.trim().split("\n").filter(l => l)
        }
    }

    Process {
        running: true
        command: ["theme-set", "palettes"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.palettes = JSON.parse(text);
                } catch (e) {
                    root.palettes = {};
                }
            }
        }
    }

    Process {
        id: previews
        property string forTheme: ""
        command: ["theme-set", "wallpaper-previews", root.dir]
        onExited: root.previewTheme = previews.forTheme
    }
    function refreshPreviews() {
        previews.running = false;
        previews.forTheme = Theme.themeName;
        previews.running = true;
    }
    Component.onCompleted: {
        root.previewTheme = Theme.themeName;
        root.refreshPreviews();
    }
    Connections {
        target: Theme
        function onThemeNameChanged() {
            root.refreshPreviews();
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper-source"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.source = text().trim()
        onLoadFailed: root.source = ""
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper-recolor"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.recolor = text().trim() !== "0"
        onLoadFailed: root.recolor = true
    }

    Process { id: runner }
    function run(args) {
        runner.running = false;
        runner.command = args;
        runner.running = true;
    }

    function applyPaper(path) {
        root.source = path;
        run(root.recolor ? ["theme-set", "wallpaper", path] : ["theme-set", "wallpaper", path, "--no-recolor"]);
    }
    function setRecolor(on) {
        if (!root.picked)
            return;
        root.recolor = on;
        run(on ? ["theme-set", "wallpaper", root.source] : ["theme-set", "wallpaper", root.source, "--no-recolor"]);
    }
}
