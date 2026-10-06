pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    readonly property var sources: ({
        repos: {
            title: "Repos",
            desc: "~/repos - opens in neovim",
            icon: "folder_code",
            hint: "Search repos",
            empty: "Nothing in ~/repos",
            list: ["sh", "-c", "ls -1d ~/repos/*/ 2>/dev/null"],
            item: line => {
                const path = line.replace(/\/+$/, "");
                return {
                    key: path,
                    name: path.split("/").pop(),
                    sub: path.replace(root.home, "~"),
                    tag: "dir"
                };
            },
            run: it => ["kitty", "--directory", it.key, "-e", "nvim", "."]
        },
        record: {
            title: "Record",
            desc: "pick the audio, then a region",
            icon: "screen_record",
            hint: "Search",
            empty: "",
            list: ["printf", "none\tno audio\nsystem\tsystem audio\nmic\tmicrophone\nboth\tsystem + microphone\n"],
            item: line => {
                const [key, name] = line.split("\t");
                return { key: key, name: name, sub: "", tag: "" };
            },
            run: it => ["record", it.key]
        }
    })

    property string active: ""
    property var items: []
    property bool loading: false

    readonly property var source: sources[active] ?? null

    function show(name) {
        if (!sources[name])
            return;
        lister.running = false;
        if (name !== active) {
            active = name;
            items = [];
        }
        loading = true;
        lister.running = true;
        NotchState.open("pick");
    }

    Process {
        id: lister
        command: root.source?.list ?? []
        stdout: StdioCollector {
            onStreamFinished: {
                const src = root.source;
                if (!src)
                    return;
                const mk = src.item ?? (l => ({ key: l, name: l, sub: "", tag: "" }));
                root.items = text.trim().split("\n").filter(l => l).map(mk);
            }
        }
        onExited: root.loading = false
    }

    function accept(key) {
        const it = items.find(i => i.key === key);
        if (!it || !source)
            return;
        Quickshell.execDetached(source.run(it));
        NotchState.close();
    }
}
