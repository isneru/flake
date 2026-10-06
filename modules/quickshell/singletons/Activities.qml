pragma Singleton
import QtQuick
import Quickshell
import "root:/singletons"

Singleton {
    id: root

    readonly property var list: Config.pillStyle === "split" ? [] : [
        NotchState.recording ? {
            key: "rec",
            icon: "screen_record",
            color: Theme.error,
            label: NotchState.fmt(NotchState.recElapsed),
            w: 276,
            blink: true
        } : null,
        LocalSend.running ? {
            key: "lsend",
            icon: LocalSend.running.dir === "in" ? "download" : "upload",
            color: Theme.accent,
            label: Math.floor(100 * LocalSend.running.sent / Math.max(1, LocalSend.running.total)) + "%",
            w: 252,
            blink: false,
            panel: "send"
        } : null,
        Downloads.count ? {
            key: "dl",
            icon: "download",
            color: Theme.accent,
            label: Downloads.label,
            w: 252,
            blink: false,
            panel: "home"
        } : null,
        NotchState.agendaChip ? {
            key: "agenda",
            icon: "",
            color: Agenda.nextEvent?.color ?? Theme.accent,
            label: Agenda.minutesTo + "m",
            w: 258,
            blink: true,
            panel: "cal"
        } : null,
        Countdown.active ? {
            key: "timer",
            icon: Countdown.paused ? "pause_circle" : "timer",
            color: Countdown.kind === "break" ? Theme.success : Theme.warning,
            label: Countdown.label,
            w: 240 + Countdown.label.length * 10,
            blink: false,
            panel: "timer"
        } : null
    ].filter(a => a)

    readonly property var active: list.length ? list[0] : null
}
