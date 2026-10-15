pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpu: 0
    property int ram: 0
    property int disk: 0
    property int temp: 0
    property real netDown: 0
    property real netUp: 0
    property var procs: []

    property string uptime: "—"
    property string hyprland: ""
    property string kernel: ""

    property int watchers: 0
    property int procWatchers: 0

    property var _prevCpu: null
    property var _prevNet: null
    property real _prevT: 0

    onWatchersChanged: {
        if (watchers > 0)
            return;
        _prevCpu = null;
        _prevNet = null;
    }

    Timer {
        interval: 1000
        running: root.watchers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            netFile.reload();
            thermFile.reload();
            upFile.reload();
            if (root.procWatchers > 0)
                topProc.running = true;
        }
    }

    FileView {
        id: upFile
        path: "/proc/uptime"
        onLoaded: {
            const s = parseFloat(text().split(" ")[0]);
            const h = Math.floor(s / 3600);
            const m = Math.floor(s % 3600 / 60);
            root.uptime = h > 0 ? h + "h " + m + "m" : m + "m";
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "hyprctl version -j | sed -n 's/.*\"version\": *\"\\([^\"]*\\)\".*/\\1/p'"]
        stdout: StdioCollector {
            onStreamFinished: root.hyprland = text.trim()
        }
    }
    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = text.trim()
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const l = text().split("\n")[0].split(/\s+/).slice(1).map(Number);
            const idle = l[3] + l[4];
            const total = l.reduce((a, b) => a + b, 0);
            if (root._prevCpu) {
                const dt = total - root._prevCpu.total;
                const di = idle - root._prevCpu.idle;
                if (dt > 0)
                    root.cpu = Math.round(100 * (1 - di / dt));
            }
            root._prevCpu = { total: total, idle: idle };
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const m = {};
            for (const line of text().split("\n")) {
                const p = line.split(":");
                if (p.length === 2)
                    m[p[0]] = parseInt(p[1]);
            }
            if (m.MemTotal)
                root.ram = Math.round(100 * (1 - m.MemAvailable / m.MemTotal));
        }
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n")) {
                const p = line.trim().split(/\s+/);
                if (p.length < 10 || p[0].startsWith("lo"))
                    continue;
                rx += parseInt(p[1]) || 0;
                tx += parseInt(p[9]) || 0;
            }
            const now = Date.now() / 1000;
            if (root._prevNet) {
                const dt = Math.max(0.2, now - root._prevT);
                root.netDown = Math.max(0, (rx - root._prevNet.rx) / dt / 1048576);
                root.netUp = Math.max(0, (tx - root._prevNet.tx) / dt / 1048576);
            }
            root._prevNet = { rx: rx, tx: tx };
            root._prevT = now;
        }
    }

    FileView {
        id: thermFile
        path: "/sys/class/thermal/thermal_zone0/temp"
        onLoaded: root.temp = Math.round(parseInt(text()) / 1000)
    }

    Process {
        id: topProc
        command: ["sh", "-c", "ps -eo comm=,pcpu=,rss= --sort=-pcpu | head -4"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.procs = text.trim().split("\n").filter(l => l).map(l => {
                    const p = l.trim().split(/\s+/);
                    return { name: p[0], cpu: parseFloat(p[1]).toFixed(1), mem: Math.round(parseInt(p[2]) / 1024) };
                });
            }
        }
    }

    Process {
        id: dfProc
        running: true
        command: ["sh", "-c", "df --output=pcent / | tail -1 | tr -dc '0-9'"]
        stdout: StdioCollector {
            onStreamFinished: root.disk = parseInt(text) || 0
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: dfProc.running = true
    }
}
