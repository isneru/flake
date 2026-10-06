pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool dnd: false
    property bool idleInhibit: false
    property bool night: false
    property int nightTemp: 4200
    property bool bt: true
    property string mediaPin: ""
    property bool bare: false
    property bool loaded: false

    function setDnd(v) { dnd = v; save(); }
    function setIdleInhibit(v) { idleInhibit = v; save(); }
    function setNight(v) { night = v; save(); }
    function setNightTemp(v) { nightTemp = v; save(); }
    function setBt(v) { bt = v; save(); }
    function setMediaPin(v) { mediaPin = v; save(); }
    function setBare(v) { bare = v; save(); }

    FileView {
        id: file
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/persist.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.apply(text()); root.loaded = true; }
        onLoadFailed: { root.loaded = true; root.save(); }
    }

    function apply(txt) {
        try {
            const j = JSON.parse(txt);
            dnd = j.dnd ?? false;
            idleInhibit = j.idleInhibit ?? false;
            night = j.night ?? false;
            nightTemp = j.nightTemp ?? 4200;
            bt = j.bt ?? true;
            mediaPin = j.mediaPin ?? "";
            bare = j.bare ?? false;
        } catch (e) {
            dnd = false;
            idleInhibit = false;
            night = false;
            nightTemp = 4200;
            bt = true;
            mediaPin = "";
            bare = false;
        }
    }

    property bool _ready: false
    Component.onCompleted: _ready = true
    function save() {
        if (!_ready)
            return;
        file.setText(JSON.stringify({
            dnd: dnd,
            idleInhibit: idleInhibit,
            night: night,
            nightTemp: nightTemp,
            bt: bt,
            mediaPin: mediaPin,
            bare: bare
        }, null, 2));
    }
}
