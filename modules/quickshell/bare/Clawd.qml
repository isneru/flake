import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "root:/singletons"

PanelWindow {
    id: root

    required property var modelData
    property int rightInset: 0
    property int room: 0

    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/claude-mascot"
    readonly property int px: Math.max(2, Math.floor((Mode.barHeight - 4) / 5))
    readonly property int staleMs: 3000
    readonly property int goneMs: 60000
    readonly property int gap: 4
    readonly property var tints: [Theme.ansiBlue, Theme.ansiGreen, Theme.ansiMagenta, Theme.ansiCyan, Theme.ansiYellow]
    property var slots: ({})
    property var shown: []
    property string tintText: ""
    readonly property int stage: 20 * root.px
    readonly property real stripX: strip.x
    readonly property real stripWidth: strip.width
    readonly property int fit: Math.max(0, Math.min(root.shown.length, Math.floor((root.room + root.gap) / (root.stage + root.gap))))

    screen: root.modelData
    visible: root.fit > 0 && Hyprland.focusedMonitor === Hyprland.monitorFor(root.modelData)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 8 * root.px + 2
    mask: Region {
        x: -1
        y: -1
        width: 1
        height: 1
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bare-clawd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function refresh(): void {
        const now = Date.now();
        const live = [];
        for (let i = 0; i < sessions.count; i++) {
            const file = sessions.objectAt(i);
            if (!file || file.isGone)
                continue;
            file.reload();
            const s = file.session;
            if (!s)
                continue;
            const age = now - s.updatedAt;
            if (s.isEnded || age > root.goneMs) {
                file.isGone = true;
                Quickshell.execDetached(["rm", "-f", file.path]);
                continue;
            }
            if (age <= root.staleMs)
                live.push({ path: file.path, session: s });
        }
        const slots = {};
        for (const l of live)
            if (root.slots[l.path] !== undefined)
                slots[l.path] = root.slots[l.path];
        for (const l of live) {
            if (slots[l.path] !== undefined)
                continue;
            let free = 0;
            while (Object.values(slots).includes(free))
                free++;
            slots[l.path] = free;
        }
        root.slots = slots;
        const tinted = {};
        for (const l of live) {
            if (slots[l.path] === 0)
                continue;
            const tint = root.tints[(slots[l.path] - 1) % root.tints.length];
            tinted[l.path.split("/").pop().replace(/\.json$/, "")] = { body: tint.toString(), shade: Qt.darker(tint, 1.45).toString() };
        }
        const tintText = JSON.stringify(tinted);
        if (tintText !== root.tintText) {
            root.tintText = tintText;
            tintFile.setText(tintText);
        }
        live.sort((a, b) => slots[a.path] - slots[b.path]);
        const isSameRow = live.length === root.shown.length && live.every((l, i) => l.path === root.shown[i].path);
        const changed = live.map((l, i) => !isSameRow || l.session !== root.shown[i].session);
        if (!changed.includes(true) && isSameRow)
            return;
        root.shown = live.map(l => ({ path: l.path, session: l.session }));
        changed.forEach((isChanged, i) => {
            if (isChanged)
                stages.itemAt(i)?.requestPaint();
        });
    }

    function clickAt(x: real): void {
        root.focusSession(root.shown[Math.floor((strip.width - x) / (root.stage + root.gap))]?.session);
    }

    function focusSession(s): void {
        if (!s?.kitty)
            return;
        Hyprland.dispatch(`hl.dsp.focus{ window = "pid:${s.kitty.pid}" }`);
        Quickshell.execDetached(["kitten", "@", "--to", `unix:/tmp/kitty-${s.kitty.pid}`, "focus-window", "--match", `id:${s.kitty.window}`]);
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: folder.folder = "file://" + root.dir
    }

    FileView {
        id: tintFile
        path: root.dir + "/.tints"
        printErrors: false
    }

    FolderListModel {
        id: folder
        nameFilters: ["*.json"]
        showDirs: false
    }

    Instantiator {
        id: sessions
        model: folder
        delegate: FileView {
            required property string filePath
            property string raw: ""
            property var session: null
            property bool isGone: false

            path: filePath
            printErrors: false
            onLoaded: {
                const t = text();
                if (t === raw)
                    return;
                raw = t;
                try {
                    session = JSON.parse(t);
                } catch (e) {}
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 150
        onTriggered: root.refresh()
    }

    Item {
        id: strip

        x: root.width - root.rightInset - width
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: Math.max(0, root.fit * (root.stage + root.gap) - root.gap)
        height: 8 * root.px

        Repeater {
            id: stages
            model: root.fit

            Canvas {
                required property int index

                x: strip.width - (index + 1) * width - index * root.gap
                width: root.stage
                height: strip.height

                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const entry = root.shown[index];
                    if (!entry)
                        return;
                    const s = entry.session;
                    for (let i = 0; i < s.pixels.length; i++) {
                        const c = s.pixels[i];
                        if (c < 0)
                            continue;
                        ctx.fillStyle = "#" + c.toString(16).padStart(6, "0");
                        ctx.fillRect(i % s.width * root.px, Math.floor(i / s.width) * root.px, root.px, root.px);
                    }
                }
            }
        }
    }
}
