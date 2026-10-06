import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import "root:/singletons"

Scope {
    id: root
    required property var modelData

    readonly property var mon: Hyprland.monitorFor(root.modelData)
    readonly property int activeWs: mon?.activeWorkspace?.id ?? 0

    readonly property var spaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor === root.mon)
        .sort((a, b) => a.id - b.id)

    readonly property var focused: Hyprland.activeToplevel
    readonly property string title: root.activeHere ? Menu.short(focused?.wayland?.appId ?? "") : ""
    readonly property bool qute: root.activeHere && Qute.running && focused?.wayland?.appId === Qute.appId
    readonly property bool yazi: root.activeHere && Yazi.running
    readonly property string monName: root.mon?.name ?? ""
    property string special: root.mon?.lastIpcObject?.specialWorkspace?.name ?? ""

    readonly property bool activeHere: {
        const id = root.focused?.workspace?.id;
        if (id === undefined)
            return false;
        return id < 0 ? root.special !== "" : id === root.activeWs;
    }

    readonly property var battery: NotchState.battery
    readonly property int pct: battery ? Math.round(battery.percentage * 100) : -1
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging

    readonly property color batteryFg: {
        if (root.pct < 0)
            return Theme.fgMuted;
        if (root.charging)
            return Theme.ansiGreen;
        if (root.pct <= 15)
            return Theme.ansiRed;
        if (root.pct <= 30)
            return Theme.ansiYellow;
        return Theme.fg;
    }

    property string uptimeText: ""
    property string popKind: ""
    readonly property bool popOpen: pop.visible

    function pick(source) {
        Quickshell.execDetached(["notch-pick", source]);
    }

    function popAt(item) {
        return item.mapToItem(null, item.width / 2, 0).x;
    }

    readonly property bool monitorOpen: popOpen && popKind === "monitor"
    onMonitorOpenChanged: {
        const d = monitorOpen ? 1 : -1;
        Sensors.watchers += d;
        Sensors.procWatchers += d;
    }
    Component.onDestruction: {
        if (!monitorOpen)
            return;
        Sensors.watchers--;
        Sensors.procWatchers--;
    }

    function openPop(kind, x, toggle) {
        if (toggle && root.popOpen && root.popKind === kind) {
            pop.close();
            return;
        }
        root.popKind = kind;
        pop.anchor = x;
        if (kind === "net")
            Net.watching = true;
        if (kind === "displays")
            Hyprland.refreshMonitors();
        root.refreshPop();
    }

    function refreshPop() {
        if (root.popKind === "clock")
            return;
        pop.image = root.popKind === "qr" && Net.qrPath ? "file://" + Net.qrPath : "";
        pop.lines = root.linesFor(root.popKind);
    }

    function eta(s) {
        return s >= 3600 ? Math.floor(s / 3600) + "h " + Math.floor(s % 3600 / 60) + "m" : Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function linesFor(kind) {
        switch (kind) {
        case "weather": {
            if (!Weather.configured)
                return ["no location set, pick one in the weather menu"];
            if (!Weather.ready)
                return [Weather.error || "loading the forecast"];
            const c = Weather.current;
            return [
                Config.weatherPlace,
                `${Weather.temp} ${Weather.info.label.toLowerCase()}, feels like ${Math.round(c.feels)}°`,
                `wind ${Math.round(c.wind)} km/h, humidity ${c.humidity}%`,
                Weather.hourly.slice(0, 6).map(h => `${Weather.hourLabel(h.time)} ${Math.round(h.temp)}°`).join("  ")
            ].concat(Weather.daily.slice(0, 5).map(d => `${Weather.dayLabel(d.date).padEnd(10)} ${String(Math.round(d.min)).padStart(3)}° to ${String(Math.round(d.max)).padStart(3)}°  ${Weather.codeInfo(d.code, true).label.toLowerCase()}`));
        }
        case "monitor":
            return [
                `cpu ${Sensors.cpu}%  ram ${Sensors.ram}%  disk ${Sensors.disk}%  temp ${Sensors.temp}°C`,
                `net down ${Sensors.netDown.toFixed(2)} MB/s  up ${Sensors.netUp.toFixed(2)} MB/s`
            ].concat(Sensors.procs.slice(0, 5).map(p => `${String(p.name).slice(0, 18).padEnd(18)} ${String(p.cpu).padStart(5)}%  ${String(p.mem).padStart(5)} MB`))
                .concat([`up ${Sensors.uptime}  hyprland ${Sensors.hyprland}  kernel ${Sensors.kernel}`]);
        case "displays":
            return Hyprland.monitors.values.map(m => {
                const g = m.lastIpcObject ?? {};
                return `${m.name}: ${g.width ?? 0}x${g.height ?? 0} @ ${Math.round(g.refreshRate ?? 0)} Hz, scale ${(g.scale ?? 1).toFixed(2)}, vrr ${g.vrr ? "on" : "off"}`
                    + (g.description ? `, "${g.description}"` : "");
            });
        case "net":
            return [
                `${Net.iface || "no route"}  down ${Net.fmtRate(Net.rxRate)}  up ${Net.fmtRate(Net.txRate)}`,
                Net.pinging ? "ping running" : (Net.pingMs >= 0 ? `ping ${Net.pingMs} ms, ${Net.pingLoss}% loss` : "ping not run"),
                Net.testing ? "speed test running" : (Net.downMbps > 0 ? `download ${Net.downMbps.toFixed(1)} Mb/s` : "speed test not run"),
                `dns ${Net.dns || "unknown"}` + (Net.dnsBusy ? `, switching to ${Net.dnsBusy.toLowerCase()}` : "")
            ];
        case "downloads":
            if (!Downloads.count)
                return ["no downloads"];
            return Downloads.items.map(d => `"${d.name}" `
                + (d.total > 0 ? Math.floor(100 * d.done / d.total) + "%" : Downloads.fmtBytes(d.done ?? 0))
                + (d.speed > 0 ? `  ${Downloads.fmtBytes(d.speed)}/s` : "")
                + (d.eta !== null && d.eta !== undefined ? `  ${root.eta(d.eta)} left` : ""));
        case "qr":
            if (Net.qrError)
                return [Net.qrError];
            return Net.qrPath ? [`scan to join "${NotchState.ssid}"`] : ["making the code"];
        }
        return [kind];
    }

    Timer {
        interval: 1000
        running: root.popOpen && root.popKind !== "clock"
        repeat: true
        onTriggered: root.refreshPop()
    }

    Connections {
        target: pop
        function onVisibleChanged(): void {
            if (pop.visible)
                return;
            if (root.popKind === "net")
                Net.watching = false;
            if (root.popKind === "qr")
                Net.clearQr();
            root.popKind = "";
        }
    }

    Connections {
        target: Mode
        function onPopRequested(kind): void {
            if (kind === "")
                pop.close();
            else if ((Hyprland.focusedMonitor?.name ?? "") === root.monName)
                root.openPop(kind, bar.width / 2, false);
        }
    }

    function agenda(): void {
        const d = new Date();
        pop.anchor = clock.mapToItem(null, clock.width / 2, 0).x;
        pop.lines = [
            Qt.formatDateTime(d, "dddd d MMMM yyyy"),
            Qt.formatDateTime(d, "HH:mm:ss"),
            root.uptimeText
        ].filter(l => l !== "");
    }

    Process {
        id: uptime
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.uptimeText = text.trim();
                if (root.popKind === "clock")
                    root.agenda();
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name !== "activespecialv2")
                return;
            const args = event.parse(3);
            if (args[2] !== root.monName)
                return;
            root.special = args[1];
        }
    }

    Pop {
        id: pop
        screen: root.modelData
    }

    Clawd {
        modelData: root.modelData
        rightInset: status.width + 8
    }

    PanelWindow {
        id: bar

        screen: root.modelData
        color: Theme.alpha(Theme.bgDim, 0.88)
        implicitHeight: Mode.barHeight

        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WlrLayershell.namespace: "quickshell-bare-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: drop.containsDrag ? Theme.accent : Theme.border
        }

        DropArea {
            id: drop
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => {
                if (!drop.hasUrls)
                    return;
                drop.acceptProposedAction();
                Shelf.add(drop.urls);
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.bottom: parent.bottom

            Repeater {
                model: root.spaces
                Seg {
                    required property var modelData
                    readonly property bool here: modelData.id === root.activeWs && root.special === ""
                    text: here ? `[${modelData.id}]` : ` ${modelData.id} `
                    fg: here ? Theme.accent : (modelData.toplevels.values.length ? Theme.fg : Theme.fgMuted)
                    onClicked: Hyprland.dispatch(`hl.dsp.focus{ workspace = ${modelData.id} }`)
                }
            }

            Seg {
                text: root.title ? root.title.slice(0, 72) : ""
                fg: Theme.fgDim
                visible: root.title !== "" && !root.qute && !root.yazi
                onClicked: root.pick("windows")
            }

            Seg {
                readonly property bool block: Qute.mode !== "normal" && Qute.mode !== "command"
                visible: root.qute
                tight: true
                minChars: block ? 0 : 4
                text: Qute.modeCode
                fg: block ? Theme.bg : Qute.mode === "normal" ? Theme.fgMuted : "transparent"
                fill: block ? Qute.modeColor : "transparent"
                interactive: block
                onClicked: Qute.send(":mode-leave")
            }

            Seg {
                visible: root.qute
                tight: true
                richText: true
                text: `[<font color="${Qute.state.back ? Theme.fg : Theme.fgMuted}">&lt;</font>`
                interactive: Qute.state.back === true
                onClicked: Qute.send(":back")
            }

            Seg {
                visible: root.qute
                tight: true
                richText: true
                text: `<font color="${Qute.state.forward ? Theme.fg : Theme.fgMuted}">&gt;</font>]`
                interactive: Qute.state.forward === true
                onClicked: Qute.send(":forward")
            }

            Seg {
                visible: root.qute
                tight: true
                text: Qute.scrollLabel
                onClicked: Qute.send(Qute.scroll <= 0 ? ":scroll-to-perc" : ":scroll-to-perc 0")
            }

            Seg {
                visible: root.qute
                tight: true
                minChars: 3 + 2 * String(Qute.state.tabs ?? 0).length
                text: `[${Qute.state.tab ?? 0}/${Qute.state.tabs ?? 0}]`
                onClicked: Qute.send(":cmd-set-text -s :tab-select")
            }

            Seg {
                visible: root.qute && Qute.url !== ""
                tight: true
                text: Qute.elide(Qute.url, 64)
                fg: Qute.urlColor
                buttons: Qt.LeftButton | Qt.RightButton
                onClicked: button => Qute.send(button === Qt.RightButton ? ":yank" : ":cmd-set-text :open {url:pretty}")
            }

            Seg {
                visible: root.qute && Qute.state.private === true
                tight: true
                text: "[private]"
                fg: Theme.accent
                interactive: false
            }

            Seg {
                visible: root.qute && Qute.match !== null
                tight: true
                minChars: Qute.match ? 9 + 2 * String(Qute.match[1]).length : 0
                text: Qute.match ? `[match ${Qute.match[0]}/${Qute.match[1]}]` : ""
                buttons: Qt.LeftButton | Qt.RightButton
                onClicked: button => Qute.send(button === Qt.RightButton ? ":search-prev" : ":search-next")
            }

            Seg {
                visible: root.qute && Qute.loading
                tight: true
                minChars: 11
                text: `[load ${Qute.state.progress ?? 0}%]`
                fg: Theme.accent
                onClicked: Qute.send(":stop")
            }

            Seg {
                visible: root.qute && Qute.keys !== ""
                tight: true
                text: `[${Qute.keys}]`
                onClicked: Qute.send(":clear-keychain")
            }

            Seg {
                visible: root.yazi
                tight: true
                minChars: 3 + 2 * String(Yazi.files).length
                text: `[${Math.min(Yazi.cursor + 1, Yazi.files)}/${Yazi.files}]`
                interactive: false
            }

            Seg {
                visible: root.yazi
                tight: true
                text: Yazi.percentLabel
                onClicked: Yazi.send("arrow", Yazi.cursor === 0 ? "bot" : "top")
            }

            Seg {
                visible: root.yazi && Yazi.permRich !== ""
                tight: true
                richText: true
                text: Yazi.permRich
                interactive: false
            }

            Seg {
                visible: root.yazi && (Yazi.state.size ?? "") !== ""
                tight: true
                minChars: 8
                text: `[${Yazi.state.size}]`
                interactive: false
            }

            Seg {
                visible: root.yazi && (Yazi.state.name ?? "") !== ""
                tight: true
                text: Qute.elide(Yazi.state.name ?? "", 64)
                buttons: Qt.LeftButton | Qt.RightButton
                onClicked: button => button === Qt.RightButton ? Yazi.send("copy", "path") : Yazi.send("rename", "--cursor=before_ext")
            }

            Seg {
                visible: root.yazi && Yazi.mode !== "normal"
                tight: true
                text: Yazi.mode.toUpperCase()
                fg: Theme.bg
                fill: Theme.ansiRed
                onClicked: Yazi.send("escape", "--visual")
            }

            Seg {
                visible: root.yazi && Yazi.tasks > 0
                tight: true
                text: `[${Yazi.state.percent !== undefined ? Yazi.state.percent + "%, " : ""}${Yazi.tasks} left]`
                fg: (Yazi.state.failed ?? 0) > 0 ? Theme.ansiRed : Theme.accent
                onClicked: Yazi.send("tasks:show")
            }
        }

        Row {
            id: status
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.bottom: parent.bottom

            Seg {
                visible: Discord.call
                text: ""
                fg: Discord.speaking ? Theme.accent : Theme.fgMuted
                interactive: false
            }

            Seg {
                id: dlSeg
                visible: Downloads.count > 0
                text: `[dl ${Downloads.label}]`
                fg: Theme.accent
                onClicked: root.openPop("downloads", root.popAt(dlSeg), true)
            }

            Seg {
                id: agendaSeg
                visible: Agenda.flash && !!Agenda.nextEvent
                text: `[${(Agenda.nextEvent?.title ?? "").replace(/^(PL|TP|T) - (\S+) - (.+)$/, "$2 $3")} ${Agenda.minutesTo}m]`
                fg: Agenda.nextEvent?.color ?? Theme.accent
                onClicked: root.pick("calendar")

                SequentialAnimation on opacity {
                    running: agendaSeg.visible
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) agendaSeg.opacity = 1
                    NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                }
            }

            Seg {
                visible: Countdown.active
                text: `[${Countdown.title.toLowerCase()} ${Countdown.label}${Countdown.paused ? " paused" : ""}]`
                fg: Countdown.paused ? Theme.fgMuted : Theme.accent
                onClicked: root.pick("timer")
            }

            Seg {
                id: weatherSeg
                visible: Weather.ready
                text: `${Weather.temp} ${Weather.info.label.toLowerCase()}`
                fg: root.popOpen && root.popKind === "weather" ? Theme.accent : Theme.fg
                onClicked: root.openPop("weather", root.popAt(weatherSeg), true)
            }

            Seg {
                text: root.pct < 0 ? "no batt" : `${root.charging ? "+" : ""}${root.pct}%`
                fg: root.batteryFg
                onClicked: root.pick("power")
            }

            Seg {
                text: NotchState.networkName || "offline"
                fg: NotchState.networkName ? Theme.fg : Theme.fgMuted
                onClicked: root.pick("wifi")
            }

            Seg {
                id: clock
                property string now: ""
                text: now
                fg: root.popOpen && root.popKind === "clock" ? Theme.accent : Theme.fg

                onClicked: {
                    if (root.popOpen && root.popKind === "clock") {
                        pop.close();
                        return;
                    }
                    root.popKind = "clock";
                    pop.image = "";
                    uptime.running = false;
                    uptime.running = true;
                }

                function tick() {
                    clock.now = Qt.formatDateTime(new Date(), "HH:mm");
                    if (root.popOpen && root.popKind === "clock")
                        root.agenda();
                }
                Component.onCompleted: tick()
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clock.tick()
                }
            }
        }
    }
}
