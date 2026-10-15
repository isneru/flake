//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "root:/singletons"
import "root:/lock"
import "root:/bare"

ShellRoot {
    Component.onCompleted: {
        Menu.sep;
        Polkit.registered;
        Notifs.strip;
        Tray.items;
        LocalSend.alive;
    }

    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    Osd {}
    Auth {}
    Share {}
    Send {}
    Cheatsheet {}

    IpcHandler {
        target: "bare"
        function pop(kind: string): void { Mode.popRequested(kind); }
        function keys(): void { Mode.cheatsheet = !Mode.cheatsheet; }
        function close(): void {
            BareState.close();
            Mode.popRequested("");
        }
        function osd(kind: string): void { BareState.showOsd(kind); }

        function screenshot(path: string): void { BareState.showOsd("shot", { path: path }); }
        function shotSaved(path: string): void { BareState.showOsd("shot", { path: path, saved: true }); }

        function volume(v: int): void { BareState.setVolume(v); }
        function brightness(v: int): void { BareState.setBrightness(v); BareState.showOsd("bri"); }

        function micMute(): void { BareState.toggleMicMute(); }
        function brightnessUp(): void { BareState.stepBrightness(5); }
        function brightnessDown(): void { BareState.stepBrightness(-5); }

        function playPause(): void { const p = BareState.mediaToggle; if (p?.canTogglePlaying) p.togglePlaying(); }
        function next(): void { const p = BareState.mediaPlayer; if (p?.canGoNext) p.next(); }
        function previous(): void { const p = BareState.mediaPlayer; if (p?.canGoPrevious) p.previous(); }
    }

    WlSessionLock {
        id: sessionLock
        locked: Lock.locked

        WlSessionLockSurface {
            color: Theme.bg
            LockSurface { anchors.fill: parent }
        }
    }

    IpcHandler {
        target: "look"
        function toggle(): string {
            Mode.toggle();
            return Mode.current();
        }
        function flat(): string {
            Mode.set(false);
            return Mode.current();
        }
        function soft(): string {
            Mode.set(true);
            return Mode.current();
        }
        function status(): string { return Mode.current(); }
    }

    IpcHandler {
        target: "menu"
        function apps(): string { return Menu.apps(); }
        function launch(id: string): string { return Menu.launch(id); }
        function open(id: string, order: string): string { return Menu.open(id, order); }
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
        function media(): string { return Menu.media(); }
        function mediaState(): string { return Menu.mediaState(); }
        function mediaAct(what: string): string { return Menu.mediaAct(what); }
        function mediaSeek(spec: string): string { return Menu.mediaSeek(spec); }
        function displays(): string { return Menu.displays(); }
        function display(name: string): string { return Menu.display(name); }
        function displayActions(name: string): string { return Menu.displayActions(name); }
        function displayOptions(name: string, key: string): string { return Menu.displayOptions(name, key); }
        function displaySet(name: string, key: string, value: string): string { return Menu.displaySet(name, key, value); }
        function displayModes(): string { return Menu.displayModes(); }
        function displayMode(mode: string): string { return Menu.displayMode(mode); }
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
        target: "qr"
        function scan(): void { Qr.scan(); }
        function last(): string { return Qr.text; }
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
            Quickshell.execDetached(["bare-pick", "send"]);
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
        function start(): void { BareState.startRecording(); }
        function stop(): void { BareState.stopRecording(); }
        function toggle(): void {
            Quickshell.execDetached(BareState.recording ? ["record"] : ["bare-pick", "record"]);
        }
    }
}
