pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property int focusSecs: 25 * 60
    readonly property int breakSecs: 5 * 60

    property string kind: ""
    property int total: 0
    property double endsAt: 0
    property int held: 0
    property int rounds: 0

    property double now: Date.now()

    readonly property bool active: kind !== ""
    readonly property bool paused: active && held > 0

    readonly property int remaining: {
        if (!active)
            return 0;
        if (held > 0)
            return held;
        return Math.max(0, Math.ceil((endsAt - now) / 1000));
    }

    readonly property real progress: total > 0 ? Math.min(1, (total - remaining) / total) : 0

    readonly property string title: kind === "focus" ? "Focus" : (kind === "break" ? "Break" : "Timer")

    function clock(s) {
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        const sec = s % 60;
        return h > 0
            ? h + ":" + String(m).padStart(2, "0") + ":" + String(sec).padStart(2, "0")
            : m + ":" + String(sec).padStart(2, "0");
    }

    readonly property string label: clock(remaining)

    Timer {
        interval: 250
        running: root.active && root.held === 0
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.remaining <= 0)
                root.finish();
        }
    }

    function start(secs, k) {
        if (!(secs > 0))
            return;
        kind = k ?? "timer";
        total = secs;
        held = 0;
        now = Date.now();
        endsAt = now + secs * 1000;
        save();
    }

    function pause() {
        if (!active || held > 0)
            return;
        held = Math.max(1, remaining);
        endsAt = 0;
        save();
    }

    function resume() {
        if (!paused)
            return;
        now = Date.now();
        endsAt = now + held * 1000;
        held = 0;
        save();
    }

    function toggle() {
        paused ? resume() : pause();
    }

    function stop() {
        kind = "";
        total = 0;
        endsAt = 0;
        held = 0;
        rounds = 0;
        save();
    }

    function extend(secs) {
        if (!active)
            return;
        total += secs;
        if (held > 0)
            held += secs;
        else
            endsAt += secs * 1000;
        save();
    }

    function finish() {
        const was = kind;
        const nextRounds = was === "focus" ? rounds + 1 : rounds;

        kind = "";
        endsAt = 0;
        held = 0;

        if (was === "focus") {
            rounds = nextRounds;
            notify("Focus done", "Take a " + Math.round(breakSecs / 60) + " minute break.");
            start(breakSecs, "break");
        } else if (was === "break") {
            notify("Break over", "Starting focus round " + (rounds + 1) + ".");
            start(focusSecs, "focus");
        } else {
            total = 0;
            notify("Time's up", "Your timer finished.");
            save();
        }
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "Timer", summary, body]);
    }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/timer.json`
        onLoaded: root.apply(text())
        onLoadFailed: root.save()
    }

    function apply(txt) {
        try {
            const j = JSON.parse(txt);
            rounds = j.rounds ?? 0;
            if (!j.kind)
                return;
            if (j.held > 0) {
                kind = j.kind;
                total = j.total ?? j.held;
                held = j.held;
                endsAt = 0;
            } else if ((j.endsAt ?? 0) > Date.now()) {
                kind = j.kind;
                total = j.total ?? 0;
                endsAt = j.endsAt;
                held = 0;
                now = Date.now();
            }
        } catch (e) {
            rounds = 0;
        }
    }

    property bool _ready: false
    Component.onCompleted: _ready = true
    function save() {
        if (!_ready)
            return;
        file.setText(JSON.stringify({
            kind: kind,
            total: total,
            endsAt: endsAt,
            held: held,
            rounds: rounds
        }, null, 2));
    }
}
