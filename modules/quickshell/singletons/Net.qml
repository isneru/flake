pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    property bool watching: false

    property string iface: ""
    property real rxRate: 0
    property real txRate: 0
    property double lastRx: 0
    property double lastTx: 0
    property double lastAt: 0

    property int pingMs: -1
    property int pingLoss: -1
    property bool pinging: false

    property real downMbps: 0
    property bool testing: false

    property string dns: ""
    readonly property var dnsPresets: [
        { label: "Automatic", servers: "" },
        { label: "Cloudflare", servers: "1.1.1.1,1.0.0.1" },
        { label: "Quad9", servers: "9.9.9.9,149.112.112.112" },
        { label: "Google", servers: "8.8.8.8,8.8.4.4" }
    ]
    property string dnsBusy: ""

    property string qrPath: ""
    property string qrError: ""
    property bool qrBusy: false

    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function fmtRate(bytesPerSec) {
        const bits = bytesPerSec * 8;
        if (bits < 1000)
            return "0 kb/s";
        if (bits < 1000000)
            return Math.round(bits / 1000) + " kb/s";
        return (bits / 1000000).toFixed(bits < 10000000 ? 1 : 0) + " Mb/s";
    }

    readonly property string sampleScript: 'i=$(awk \'$2=="00000000" && $8=="00000000" {print $1; exit}\' /proc/net/route); [ -n "$i" ] || exit 0; printf "%s %s %s\\n" "$i" "$(cat /sys/class/net/$i/statistics/rx_bytes)" "$(cat /sys/class/net/$i/statistics/tx_bytes)"'

    Process {
        id: sampler
        command: ["sh", "-c", root.sampleScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                if (parts.length !== 3)
                    return;
                const now = Date.now();
                const rx = parseFloat(parts[1]);
                const tx = parseFloat(parts[2]);

                if (root.iface === parts[0] && root.lastAt > 0) {
                    const dt = (now - root.lastAt) / 1000;
                    if (dt > 0.2) {
                        root.rxRate = Math.max(0, (rx - root.lastRx) / dt);
                        root.txRate = Math.max(0, (tx - root.lastTx) / dt);
                    }
                } else {
                    root.rxRate = 0;
                    root.txRate = 0;
                }

                root.iface = parts[0];
                root.lastRx = rx;
                root.lastTx = tx;
                root.lastAt = now;
            }
        }
    }

    Timer {
        interval: 1000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!sampler.running) sampler.running = true
    }

    onWatchingChanged: {
        if (!watching) {
            lastAt = 0;
            rxRate = 0;
            txRate = 0;
        } else {
            readDns();
        }
    }

    Process {
        id: pinger
        stdout: StdioCollector {
            onStreamFinished: {
                const loss = text.match(/(\d+)% packet loss/);
                const rtt = text.match(/=\s*[\d.]+\/([\d.]+)\//);
                root.pingLoss = loss ? parseInt(loss[1]) : -1;
                root.pingMs = rtt ? Math.round(parseFloat(rtt[1])) : -1;
                root.pinging = false;
            }
        }
    }

    function runPing() {
        if (pinging)
            return;
        pinging = true;
        pingMs = -1;
        pingLoss = -1;
        pinger.command = ["ping", "-c", "5", "-W", "2", "-q", "1.1.1.1"];
        pinger.running = true;
    }

    Process {
        id: speeder
        stdout: StdioCollector {
            onStreamFinished: {
                const bytes = parseFloat(text.trim());
                root.downMbps = bytes > 0 ? (bytes * 8) / 1000000 : 0;
                root.testing = false;
            }
        }
    }

    function runSpeed() {
        if (testing)
            return;
        testing = true;
        downMbps = 0;
        speeder.command = ["curl", "-o", "/dev/null", "-s", "--max-time", "25",
            "-w", "%{speed_download}", "https://speed.cloudflare.com/__down?bytes=30000000"];
        speeder.running = true;
    }

    Process {
        id: dnsReader
        command: ["sh", "-c", "awk '/^nameserver/ {print $2}' /etc/resolv.conf | head -2 | paste -sd,"]
        stdout: StdioCollector {
            onStreamFinished: {
                const servers = text.trim();
                root.dns = servers.length ? servers : "none";
            }
        }
    }

    function readDns() {
        if (!dnsReader.running)
            dnsReader.running = true;
    }

    Process {
        id: dnsSetter
        onExited: {
            root.dnsBusy = "";
            dnsDelay.restart();
        }
    }

    Timer {
        id: dnsDelay
        interval: 900
        onTriggered: root.readDns()
    }

    readonly property string routedUuid: 'i=$(awk \'$2=="00000000" && $8=="00000000" {print $1; exit}\' /proc/net/route); '
        + '[ -n "$i" ] || exit 1; '
        + 'u=$(nmcli -t -f DEVICE,UUID connection show --active | awk -F: -v d="$i" \'$1==d{print $2; exit}\'); '
        + '[ -n "$u" ] || exit 1'

    function setDns(label, servers) {
        if (dnsBusy !== "")
            return;
        dnsBusy = label;
        const set = servers === ""
            ? 'ipv4.ignore-auto-dns no ipv4.dns "" ipv6.ignore-auto-dns no ipv6.dns ""'
            : `ipv4.ignore-auto-dns yes ipv4.dns "${servers}" ipv6.ignore-auto-dns yes ipv6.dns ""`;
        dnsSetter.command = ["sh", "-c",
            `${routedUuid}; nmcli connection modify "$u" ${set} && nmcli connection up "$u" >/dev/null`];
        dnsSetter.running = true;
    }

    readonly property var qrErrors: ({
        "2": "no Wi-Fi connection to share",
        "3": "enterprise networks cannot be shared",
        "4": "could not read the passphrase"
    })

    Process {
        id: qrMaker
        onExited: code => {
            root.qrBusy = false;
            root.qrError = code === 0 ? "" : (root.qrErrors[String(code)] ?? "could not build the code");
            root.qrPath = code === 0 ? root.runtime + "/quickshell-wifi.png" : "";
        }
    }

    function makeQr() {
        if (qrBusy)
            return;
        qrBusy = true;
        qrError = "";
        qrPath = "";
        qrMaker.command = ["sh", "-c",
            'esc() { printf "%s" "$1" | sed \'s/[\\\\;,:"]/\\\\&/g\'; }; '
            + 'd=$(nmcli -t -f TYPE,DEVICE device status | awk -F: \'$1=="wifi"{print $2; exit}\'); '
            + '[ -n "$d" ] || exit 2; '
            + 'u=$(nmcli -t -f DEVICE,UUID connection show --active | awk -F: -v x="$d" \'$1==x{print $2; exit}\'); '
            + '[ -n "$u" ] || exit 2; '
            + 's=$(nmcli -s -g 802-11-wireless.ssid connection show "$u"); '
            + '[ -n "$s" ] || exit 2; '
            + 'k=$(nmcli -s -g 802-11-wireless-security.key-mgmt connection show "$u"); '
            + 'case "$k" in '
            + '"") printf \'WIFI:T:nopass;S:%s;;\' "$(esc "$s")" | qrencode -m 2 -s 8 -o "$1"; exit 0 ;; '
            + 'sae) t=SAE ;; wpa-psk|wpa-psk-sha256) t=WPA ;; *) exit 3 ;; esac; '
            + 'p=$(nmcli -s -g 802-11-wireless-security.psk connection show "$u"); '
            + '[ -n "$p" ] || exit 4; '
            + 'printf \'WIFI:T:%s;S:%s;P:%s;;\' "$t" "$(esc "$s")" "$(esc "$p")" | qrencode -m 2 -s 8 -o "$1"',
            "sh", runtime + "/quickshell-wifi.png"];
        qrMaker.running = true;
    }

    function clearQr() {
        qrPath = "";
        qrError = "";
        Quickshell.execDetached(["rm", "-f", runtime + "/quickshell-wifi.png"]);
    }
}
