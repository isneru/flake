//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "root:/singletons"
import "root:/lock"

ShellRoot {
    Component.onCompleted: {
        Menu.sep;
        Polkit.registered;
        Notifs.count;
        Tray.items;
        Wall.papers;
        LocalSend.alive;
    }

    LazyLoader {
        active: !Mode.bare
        source: "root:/NotchRoot.qml"
    }

    LazyLoader {
        active: Mode.bare
        source: "root:/BareRoot.qml"
    }

    IpcHandler {
        target: "notch"
        function toggle(): void {
            if (Mode.route("home"))
                return;
            NotchState.isExpanded ? NotchState.close() : NotchState.activate();
        }
        function open(panel: string): void { if (!Mode.route(panel)) NotchState.open(panel); }
        function toggleOpen(panel: string): void {
            if (Mode.route(panel))
                return;
            NotchState.isExpanded && NotchState.panel === panel ? NotchState.close() : NotchState.open(panel);
        }
        function close(): void {
            NotchState.close();
            Mode.popRequested("");
        }
        function osd(kind: string): void { NotchState.showOsd(kind); }

        function screenshot(path: string): void { NotchState.showOsd("shot", { path: path }); }
        function shotSaved(path: string): void { NotchState.showOsd("shot", { path: path, saved: true }); }

        function volume(v: int): void { NotchState.setVolume(v); }
        function brightness(v: int): void { NotchState.setBrightness(v); NotchState.showOsd("bri"); }

        function micMute(): void { NotchState.toggleMicMute(); }
        function brightnessUp(): void { NotchState.stepBrightness(5); }
        function brightnessDown(): void { NotchState.stepBrightness(-5); }

        function playPause(): void { const p = NotchState.mediaToggle; if (p?.canTogglePlaying) p.togglePlaying(); }
        function next(): void { const p = NotchState.mediaPlayer; if (p?.canGoNext) p.next(); }
        function previous(): void { const p = NotchState.mediaPlayer; if (p?.canGoPrevious) p.previous(); }
    }

    WlSessionLock {
        id: sessionLock
        locked: Lock.locked

        WlSessionLockSurface {
            color: Theme.light ? Theme.bg : "black"
            LockSurface { anchors.fill: parent }
        }
    }

    IpcHandler {
        target: "mode"
        function toggle(): string { return Mode.toggle() ? Mode.current() : "busy"; }
        function bare(): string { return Mode.set(true) ? "bare" : Mode.current(); }
        function notch(): string { return Mode.set(false) ? "notch" : Mode.current(); }
        function status(): string { return Mode.current(); }
    }

    IpcHandler {
        target: "menu"
        function apps(): string { return Menu.apps(); }
        function launch(id: string): string { return Menu.launch(id); }
        function tray(): string { return Menu.tray(); }
        function trayActivate(id: string): string { return Menu.trayActivate(id); }
        function trayOpen(id: string): string { return Menu.trayOpen(id); }
        function traySub(index: int): string { return Menu.traySub(index); }
        function trayRows(): string { return Menu.trayRows(); }
        function trayTrigger(index: int): string { return Menu.trayTrigger(index); }
        function trayClose(): string { return Menu.trayClose(); }
        function sendState(): string { return Menu.sendState(); }
        function sendPeers(): string { return Menu.sendPeers(); }
        function sendStage(path: string): string { return Menu.sendStage(path); }
        function sendShelf(): string { return Menu.sendShelf(); }
        function sendPaste(): string { return Menu.sendPaste(); }
        function sendCompose(text: string): string { return Menu.sendCompose(text); }
        function sendClear(): string { return Menu.sendClear(); }
        function sendScan(): string { return Menu.sendScan(); }
        function sendTo(fingerprint: string): string { return Menu.sendTo(fingerprint); }
        function players(): string { return Menu.players(); }
        function pin(key: string): string { return Menu.pin(key); }
        function focus(addr: string): string { return Menu.focus(addr); }
        function control(): string { return Menu.control(); }
        function controlState(): string { return Menu.controlState(); }
        function controlToggle(key: string): string { return Menu.controlToggle(key); }
        function nightTemp(k: int): string { return Menu.nightTemp(k); }
        function bt(): string { return Menu.bt(); }
        function btPower(): string { return Menu.btPower(); }
        function btScan(): string { return Menu.btScan(); }
        function btStopScan(): string { return Menu.btStopScan(); }
        function btDevice(addr: string): string { return Menu.btDevice(addr); }
        function btVisible(): string { return Menu.btVisible(); }
        function btActions(addr: string): string { return Menu.btActions(addr); }
        function btAct(addr: string, what: string): string { return Menu.btAct(addr, what); }
        function audio(): string { return Menu.audio(); }
        function audioDefault(key: string): string { return Menu.audioDefault(key); }
        function audioLevel(key: string, v: int): string { return Menu.audioLevel(key, v); }
        function audioMute(key: string): string { return Menu.audioMute(key); }
        function notifs(): string { return Menu.notifs(); }
        function notifActions(key: string): string { return Menu.notifActions(key); }
        function notifAct(key: string, what: string): string { return Menu.notifAct(key, what); }
        function notifClear(): string { return Menu.notifClear(); }
        function cal(): string { return Menu.cal(); }
        function calState(): string { return Menu.calState(); }
        function calActions(id: string): string { return Menu.calActions(id); }
        function calAct(id: string, what: string): string { return Menu.calAct(id, what); }
        function calAdd(text: string): string { return Menu.calAdd(text); }
        function calSync(): string { return Menu.calSync(); }
        function netRefresh(): string { return Menu.netRefresh(); }
        function net(): string { return Menu.net(); }
        function netAct(what: string): string { return Menu.netAct(what); }
        function weather(): string { return Menu.weather(); }
        function weatherAct(what: string): string { return Menu.weatherAct(what); }
        function weatherSearch(q: string): string { return Menu.weatherSearch(q); }
        function weatherSearching(): string { return Menu.weatherSearching(); }
        function weatherPlaces(): string { return Menu.weatherPlaces(); }
        function weatherPick(i: int): string { return Menu.weatherPick(i); }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Lock.lock(); }
        function status(): string { return Lock.locked ? "locked" : "unlocked"; }
    }

    IpcHandler {
        target: "ask"
        function request(json: string): string { return Auth.request(json); }
        function pending(): int { return Auth.queue.length; }
        function cancel(): void { Auth.cancelAll(); }
    }

    IpcHandler {
        target: "pick"
        function open(name: string): void { if (!Mode.route(name)) Picks.show(name); }
        function list(): string { return Object.keys(Picks.sources).join("\n"); }
    }

    IpcHandler {
        target: "qr"
        function scan(): void { Qr.scan(); }
        function last(): string { return Qr.text; }
    }

    IpcHandler {
        target: "notifs"
        function replay(n: int): string {
            if (!Notifs.count)
                return "nothing to replay";
            Notifs.replay(n);
            return "replaying " + Math.min(n || 5, Notifs.count);
        }
        function clear(): void { Notifs.clearAll(); }
        function count(): int { return Notifs.count; }
    }

    IpcHandler {
        target: "shelf"
        function add(path: string): string {
            return Shelf.add([path]) ? "added" : "not added";
        }
        function list(): string { return Shelf.items.map(i => i.path).join("\n"); }
        function count(): int { return Shelf.count; }
        function clear(): void { Shelf.clear(); }
        function rows(): string {
            const home = Quickshell.env("HOME");
            return Shelf.items.map(i => {
                const tag = i.state === "missing" ? " [missing]" : "";
                const slash = i.state === "dir" ? "/" : "";
                return `${i.path}\t"${Shelf.name(i.path)}${slash}" (${Shelf.dir(i.path).replace(home, "~")})${tag}`;
            }).join("\n");
        }
        function open(path: string): void { Shelf.open(path); }
        function reveal(path: string): void {
            const it = Shelf.items.find(i => i.path === path);
            if (it)
                Shelf.reveal(it);
        }
        function copy(path: string): void { Shelf.copyFile(path); }
        function copyPath(path: string): void { Shelf.copyPath(path); }
        function remove(path: string): void { Shelf.remove(path); }
    }

    IpcHandler {
        target: "timer"
        function start(seconds: int): string {
            if (seconds <= 0)
                return "seconds must be positive";
            Countdown.start(seconds, "timer");
            return "running " + Countdown.label;
        }
        function focus(): void { Countdown.start(Countdown.focusSecs, "focus"); }
        function toggle(): void { Countdown.toggle(); }
        function stop(): void { Countdown.stop(); }
        function extend(seconds: int): void { Countdown.extend(seconds); }
        function status(): string {
            return Countdown.active
                ? Countdown.title + " " + Countdown.label + (Countdown.paused ? " (paused)" : "")
                : "idle";
        }
    }

    IpcHandler {
        target: "share"
        function request(json: string): string { return Screencast.request(json); }
        function region(sel: string): void { Screencast.region(sel); }
        function cancel(id: string): void { Screencast.abandon(id); }
        function forget(): void { Screencast.forget(); }
    }

    IpcHandler {
        target: "localsend"
        function send(path: string): string {
            if (!LocalSend.stage([path]))
                return "not a local file";
            NotchState.open("send");
            return "staged " + LocalSend.outbox.length;
        }
        function to(device: string): string {
            const p = LocalSend.peers.find(x => x.alias === device || x.ip === device);
            if (!p)
                return "no such device";
            if (!LocalSend.outbox.length)
                return "nothing staged";
            const n = LocalSend.outbox.length;
            LocalSend.sendTo(p);
            return "sending " + n + " to " + p.alias;
        }
        function paste(): string {
            LocalSend.paste();
            return "reading the clipboard";
        }
        function scan(): void { LocalSend.scan(); }
        function accept(id: string): void { LocalSend.accept(id); }
        function deny(id: string): void { LocalSend.deny(id); }
        function cancel(id: string): void { LocalSend.cancel(id); }
        function peers(): string {
            return LocalSend.peers.map(p => p.alias + "\t" + p.ip).join("\n");
        }
        function status(): string {
            if (!LocalSend.alive)
                return "daemon not running";
            const t = LocalSend.running;
            if (t)
                return t.dir + " " + t.name + " " + Math.floor(100 * t.sent / Math.max(1, t.total)) + "%";
            return LocalSend.ask ? "asking: " + LocalSend.ask.alias : "idle";
        }
    }

    IpcHandler {
        target: "recording"
        function start(): void { NotchState.startRecording(); }
        function stop(): void { NotchState.stopRecording(); }
        function toggle(): void {
            if (NotchState.recording)
                Quickshell.execDetached(["record"]);
            else if (!Mode.route("record"))
                Picks.show("record");
        }
    }
}
