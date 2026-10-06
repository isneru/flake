pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var events: []
    property string updated: ""
    property bool connected: false
    property bool syncing: sync.running

    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/agenda.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.events = data.events ?? [];
                root.updated = data.updated ?? "";
                root.connected = true;
            } catch (e) {
                root.events = [];
                root.connected = false;
            }
        }
        onLoadFailed: {
            root.events = [];
            root.connected = false;
        }
    }

    Process {
        id: sync
        command: ["gcal", "sync"]
    }

    Process {
        id: writer
    }

    Process {
        id: opener
    }

    function launch(url) {
        if (opener.running || !url)
            return;
        opener.command = ["xdg-open", url];
        opener.running = true;
    }

    readonly property bool writing: writer.running

    function refresh() {
        if (!sync.running)
            sync.running = true;
    }

    function add(text) {
        if (writer.running || !text.trim())
            return;
        writer.command = ["gcal", "add", text.trim()];
        writer.running = true;
    }

    function remove(e) {
        if (writer.running || !e)
            return;
        writer.command = ["gcal", "rm", e.calendarId, e.id];
        writer.running = true;
    }

    property double now: Date.now()

    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    readonly property var timed: root.events.filter(e => !e.allDay)
    readonly property var ongoing: root.timed.find(e => new Date(e.start).getTime() <= root.now && new Date(e.end).getTime() > root.now) ?? null
    readonly property var nextEvent: root.timed.find(e => new Date(e.start).getTime() > root.now) ?? null
    readonly property var allDayToday: root.eventsOn(new Date(root.now)).find(e => e.allDay) ?? null
    readonly property var current: root.ongoing ?? root.nextEvent ?? root.allDayToday
    function minutesUntil(e) {
        return Math.max(1, Math.ceil((new Date(e.start).getTime() - root.now) / 60000));
    }

    readonly property int minutesTo: root.nextEvent ? root.minutesUntil(root.nextEvent) : -1

    readonly property var marks: [60, 45, 30, 15, 5]
    property string flashKey: ""
    property var flashed: []
    property bool flash: false

    onMinutesToChanged: root.checkFlash()
    onNextEventChanged: root.checkFlash()

    Timer {
        id: flashTimer
        interval: 5000
        onTriggered: root.flash = false
    }

    function checkFlash() {
        const e = root.nextEvent;
        if (!e) {
            root.flash = false;
            root.flashKey = "";
            root.flashed = [];
            return;
        }
        const key = e.uid + e.start;
        if (key !== root.flashKey) {
            root.flashKey = key;
            root.flashed = [];
        }
        const mins = root.minutesUntil(e);
        const due = root.marks.filter(m => mins <= m && !root.flashed.includes(m));
        if (!due.length)
            return;
        root.flashed = root.flashed.concat(due);
        root.flash = true;
        flashTimer.restart();
    }

    function headline(e) {
        if (!e)
            return "";
        return e.allDay ? "all day" : `${root.hhmm(e.start)} - ${root.untilText(e)}`;
    }

    function untilText(e) {
        if (!e)
            return "";
        if (e.allDay)
            return "all day";
        const start = new Date(e.start).getTime();
        if (start <= root.now)
            return "now";
        const mins = Math.ceil((start - root.now) / 60000);
        if (mins < 60)
            return `in ${mins}m`;
        const day = new Date(e.start);
        const today = new Date(root.now);
        if (root.sameDay(day, today))
            return `in ${Math.round(mins / 60)}h`;
        const tomorrow = new Date(root.now);
        tomorrow.setDate(tomorrow.getDate() + 1);
        return root.sameDay(day, tomorrow) ? `tomorrow ${root.hhmm(e.start)}` : Qt.formatDateTime(day, "ddd HH:mm");
    }

    function startOf(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
    }

    function eventsOn(date) {
        const lo = root.startOf(date);
        const hi = lo + 86400000;
        return root.events.filter(e => new Date(e.end).getTime() > lo && new Date(e.start).getTime() < hi);
    }

    function countOn(date) {
        return root.eventsOn(date).length;
    }

    function sameDay(a, b) {
        return root.startOf(a) === root.startOf(b);
    }

    function hhmm(stamp) {
        return Qt.formatDateTime(new Date(stamp), "HH:mm");
    }

    function span(e) {
        return e.allDay ? "all day" : `${root.hhmm(e.start)} - ${root.hhmm(e.end)}`;
    }
}
