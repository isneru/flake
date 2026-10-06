pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    property var queue: []

    readonly property var ask: queue.length > 0 ? queue[0] : null

    readonly property bool polkit: Polkit.pending
    readonly property bool pending: polkit || ask !== null

    readonly property string source: polkit ? "polkit" : (ask ? ask.source : "")
    readonly property string kind: polkit ? "password" : (ask?.kind ?? "password")
    readonly property bool confirming: kind === "confirm"
    readonly property bool displaying: kind === "display"

    readonly property string caption: polkit ? "AUTHORIZATION REQUIRED" : (ask?.caption ?? "AUTHENTICATION REQUIRED")
    readonly property string icon: polkit ? "admin_panel_settings" : (ask?.icon ?? "key")
    readonly property string message: polkit ? (Polkit.flow?.message ?? "") : (ask?.message ?? "")

    readonly property string detailLabel: polkit ? "ACTION" : (ask?.detailLabel ?? "ASKED BY")
    readonly property string detail: polkit ? (Polkit.flow?.actionId ?? "") : (ask?.detail ?? "")

    readonly property string prompt: polkit ? (Polkit.flow?.inputPrompt || "Password") : (ask?.prompt ?? "Password")
    readonly property bool echo: polkit ? (Polkit.flow?.responseVisible ?? false) : (ask?.echo ?? false)
    readonly property bool inputEnabled: polkit ? (Polkit.flow?.isResponseRequired ?? false) : true

    readonly property string status: polkit ? (Polkit.flow?.supplementaryMessage ?? "") : (ask?.status ?? "")
    readonly property bool statusIsError: polkit ? (Polkit.flow?.supplementaryIsError ?? false) : false

    readonly property bool canRemember: !polkit && (ask?.remember ?? false)

    readonly property string footer: polkit
        ? "polkit - denying is safe; nothing runs without your password"
        : (ask?.footer ?? "")

    readonly property string confirmLabel: displaying ? "Done" : (confirming ? "Yes" : "Authorize")
    readonly property string denyLabel: displaying ? "Cancel" : (confirming ? "No" : "Deny")

    onAskChanged: ask ? expiry.restart() : expiry.stop()

    Timer {
        id: expiry
        interval: 180000
        onTriggered: root.cancel()
    }

    function request(json) {
        let req;
        try {
            req = JSON.parse(json);
        } catch (e) {
            return "bad request";
        }
        if (!req.id || !req.fifo)
            return "bad request";
        enqueue(req);
        return "queued";
    }

    function enqueue(req) {
        queue = queue.concat([
            {
                id: req.id,
                fifo: req.fifo,
                source: req.source ?? "ask",
                kind: ["confirm", "display"].indexOf(req.kind) >= 0 ? req.kind : "password",
                caption: req.caption ?? "AUTHENTICATION REQUIRED",
                icon: req.icon ?? "key",
                message: req.message ?? "",
                detail: req.detail ?? "",
                detailLabel: req.detailLabel ?? "ASKED BY",
                prompt: req.prompt ?? "Password",
                echo: req.echo === true,
                remember: req.remember === true,
                status: req.status ?? "",
                footer: req.footer ?? ""
            }
        ]);
        NotchState.open("auth");
    }

    function submit(value, remember) {
        if (polkit) {
            Polkit.submit(value);
            return;
        }
        if (!ask)
            return;
        answer(ask, (remember ? "ok-remember\n" : "ok\n") + value);
    }

    function confirm() {
        if (!polkit && ask)
            answer(ask, "ok\n");
    }

    function cancel() {
        if (polkit) {
            Polkit.cancel();
            return;
        }
        if (ask)
            answer(ask, "cancel\n");
    }

    function cancelAll() {
        if (polkit)
            Polkit.cancel();
        const rest = queue.slice();
        queue = [];
        for (const req of rest)
            answer(req, "cancel\n");
    }

    function answer(req, payload) {
        queue = queue.filter(q => q.id !== req.id);
        replier.createObject(root, {
            fifo: req.fifo,
            payload: payload
        });
        if (queue.length > 0)
            NotchState.open("auth");
    }

    Component {
        id: replier

        Process {
            required property string fifo
            required property string payload

            command: ["timeout", "10", "sh", "-c", 'test -p "$1" && exec cat > "$1"', "sh", fifo]
            running: true
            stdinEnabled: true

            onStarted: {
                write(payload);
                stdinEnabled = false;
            }
            onExited: destroy()
        }
    }
}
