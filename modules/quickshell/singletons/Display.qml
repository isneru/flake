pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    readonly property var fields: ["mode", "position", "scale", "transform", "vrr", "mirror", "disabled"]

    property var rules: ({})

    FileView {
        id: file
        path: root.dir + "/monitors"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rules = root.parse(text())
        onLoadFailed: root.rules = ({})
    }

    function parse(t) {
        const out = ({});
        for (const line of (t ?? "").split("\n")) {
            if (!line.trim())
                continue;
            const cells = line.split("\t");
            const rule = ({});
            root.fields.forEach((f, i) => {
                if ((cells[i + 1] ?? "") !== "")
                    rule[f] = cells[i + 1];
            });
            out[cells[0]] = rule;
        }
        return out;
    }

    function serialize() {
        const lines = [];
        for (const name of Object.keys(root.rules)) {
            const rule = root.rules[name];
            if (!Object.keys(rule).length)
                continue;
            lines.push([name].concat(root.fields.map(f => rule[f] ?? "")).join("\t"));
        }
        return lines.length ? lines.join("\n") + "\n" : "\n";
    }

    function ruleFor(name) {
        return root.rules[name] ?? ({});
    }

    function enabledCount() {
        return Hyprland.monitors.values.filter(m => (root.ruleFor(m.name).disabled ?? "") !== "1").length;
    }

    function set(name, key, value) {
        if (key === "disabled" && value === "1" && root.enabledCount() <= 1)
            return false;
        const next = Object.assign({}, root.rules);
        const rule = Object.assign({}, next[name] ?? ({}));
        if (value === "" || value === null)
            delete rule[key];
        else
            rule[key] = String(value);
        next[name] = rule;
        root.rules = next;
        root.apply();
        return true;
    }

    function reset(name) {
        const next = Object.assign({}, root.rules);
        delete next[name];
        root.rules = next;
        root.apply();
    }

    function apply() {
        file.setText(root.serialize());
        Quickshell.execDetached(["hyprctl", "reload"]);
    }
}
