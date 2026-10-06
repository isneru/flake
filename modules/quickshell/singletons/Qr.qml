pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    property string text: ""
    property string error: ""
    property bool scanning: false

    readonly property bool hasResult: text !== ""

    readonly property string kind: {
        if (text.startsWith("WIFI:"))
            return "Wi-Fi network";
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(text))
            return "Link";
        if (text.startsWith("mailto:"))
            return "Email";
        if (text.startsWith("BEGIN:VCARD"))
            return "Contact card";
        return "Text";
    }

    readonly property string resultPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-qr"

    FileView {
        id: result
        path: root.resultPath
        onLoaded: root.consume(text())
    }

    Timer {
        id: poll
        interval: 400
        repeat: true
        running: root.scanning
        property int ticks: 0
        onRunningChanged: ticks = 0
        onTriggered: {
            ticks++;
            if (ticks > 300) {
                root.finish("", "selector timed out");
                return;
            }
            result.reload();
        }
    }

    function consume(raw) {
        if (!root.scanning || raw.length === 0)
            return;
        Quickshell.execDetached(["rm", "-f", root.resultPath]);
        if (raw.startsWith("OK "))
            finish(raw.slice(3), "");
        else if (raw === "NONE")
            finish("", "no QR code in that region");
        else
            finish("", "selection cancelled");
    }

    function finish(decoded, err) {
        scanning = false;
        text = decoded;
        error = err;
        if (decoded.length) {
            const short = decoded.length > 46 ? decoded.slice(0, 46) + "…" : decoded;
            NotchState.showOsd("qrres", { label: "QR Scanned", sub: short });
        } else {
            NotchState.showOsd("qrres", { label: "No QR found", sub: err });
        }
    }

    function scan() {
        if (scanning)
            return;
        scanning = true;
        text = "";
        error = "";
        NotchState.close();
        Quickshell.execDetached(["qrscan"]);
    }

    function clear() {
        text = "";
        error = "";
    }
}
