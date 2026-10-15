pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var groups: [root.menu]

    readonly property var menu: ({
        title: "INSIDE A MENU",
        items: [
            ["ESC", "Close it"],
            ["UP / DOWN", "Move the selection"],
            ["CTRL+N / CTRL+P", "Move the selection"],
            ["ENTER", "Pick the selection"],
            ["SHIFT+ENTER", "Use what you typed"],
            ["TAB", "Complete to the selection"]
        ]
    })

    readonly property var mods: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    readonly property var names: ({
            "mouse:272": "left-drag",
            "mouse:273": "right-drag",
            "mouse_down": "wheel",
            "mouse_up": "wheel",
            "ESCAPE": "ESC",
            "PERIOD": ".",
            "COMMA": ",",
            "plus": "+",
            "minus": "-"
        })
    readonly property var families: [[["UP", "DOWN", "LEFT", "RIGHT"], "ARROWS"], [["H", "J", "K", "L"], "HJKL"], [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], "1…0"]]

    function refresh(): void {
        reader.running = true;
    }

    function collapse(keys) {
        let out = keys.slice();
        for (const [set, name] of root.families) {
            if (!set.every(k => out.includes(k)))
                continue;
            const at = Math.min(...set.map(k => out.indexOf(k)));
            out = out.filter(k => !set.includes(k));
            out.splice(at, 0, name);
        }
        return out;
    }

    function format(combos) {
        const byMods = [];
        for (const c of combos) {
            let m = byMods.find(x => x.mods === c.mods);
            if (!m) {
                m = { mods: c.mods, keys: [] };
                byMods.push(m);
            }
            if (!m.keys.includes(c.key))
                m.keys.push(c.key);
        }
        return byMods.map(m => m.mods + root.collapse(m.keys).join(" / ")).join(" / ");
    }

    function parse(text) {
        let binds;
        try {
            binds = JSON.parse(text);
        } catch (e) {
            return;
        }
        const groups = [];
        for (const b of binds) {
            if (!b.has_description)
                continue;
            const [title, label, keys] = b.description.split("\t");
            if (!label)
                continue;
            let g = groups.find(x => x.title === title);
            if (!g) {
                g = { title: title, rows: [] };
                groups.push(g);
            }
            let r = g.rows.find(x => x.label === label);
            if (!r) {
                r = { label: label, keys: keys ?? "", combos: [] };
                g.rows.push(r);
            }
            r.combos.push({
                mods: root.mods.filter(([bit]) => b.modmask & bit).map(([, n]) => n + "+").join(""),
                key: root.names[b.key] ?? String(b.key).toUpperCase()
            });
        }
        root.groups = groups.map(g => ({
                    title: g.title,
                    items: g.rows.map(r => [r.keys || root.format(r.combos), r.label])
                })).concat([root.menu]);
    }

    Component.onCompleted: root.refresh()

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
}
