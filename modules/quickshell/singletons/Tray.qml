pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property var items: SystemTray.items
    property var procs: []
    property bool scanning: scan.running

    readonly property string resolver: `
import json, subprocess as s

def bc(*a):
    return s.run(["busctl", "--user", "--json=short", *a], capture_output=True, text=True, timeout=3)

W = "org.kde.StatusNotifierWatcher"
out = []
r = bc("get-property", W, "/StatusNotifierWatcher", W, "RegisteredStatusNotifierItems")
if r.returncode == 0:
    for e in json.loads(r.stdout).get("data", []):
        svc, _, path = e.partition("/")
        path = "/" + path if path else "/StatusNotifierItem"
        pid = 0
        p = bc("call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", svc)
        if p.returncode == 0:
            d = json.loads(p.stdout).get("data", [0])
            pid = d[0] if isinstance(d, list) else d
        sid = ""
        i = bc("get-property", svc, path, "org.kde.StatusNotifierItem", "Id")
        if i.returncode == 0:
            sid = json.loads(i.stdout).get("data", "")
        name = ""
        cmd = ""
        try:
            name = open("/proc/%d/comm" % pid).read().strip()
            cmd = open("/proc/%d/cmdline" % pid).read().replace("\\0", " ").strip()
            base = cmd.split(" ")[0].rsplit("/", 1)[-1].lstrip(".")
            if base.endswith("-wrapped"):
                base = base[:-8]
            name = base or name
        except Exception:
            pass
        out.append({"id": sid, "pid": pid, "name": name, "cmd": cmd, "service": svc})
print(json.dumps(out))
`

    function refresh() {
        scan.running = false;
        scan.running = true;
    }

    function procFor(id) {
        for (const p of procs)
            if (p.id === id)
                return p;
        return null;
    }

    function kill(pid, force) {
        if (!pid)
            return;
        killer.running = false;
        killer.command = ["kill", force ? "-9" : "-15", String(pid)];
        killer.running = true;
    }

    Process { id: killer }

    Process {
        id: scan
        command: ["python3", "-c", root.resolver]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.procs = JSON.parse(text) || [];
                } catch (e) {
                    root.procs = [];
                }
            }
        }
    }
}
