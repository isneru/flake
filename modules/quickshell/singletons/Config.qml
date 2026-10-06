pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string pillStyle: "notch"
    property string expandAnim: "spring"
    property string ccLayout: "grid"
    property string weatherPlace: ""
    property real weatherLat: 0
    property real weatherLon: 0

    readonly property var pillStyles: ["notch", "inset", "split"]
    readonly property var expandAnims: ["spring", "unfold", "liquid"]
    readonly property var ccLayouts: ["grid", "rows"]

    function setPill(v) { pillStyle = pillStyles.includes(v) ? v : "notch"; save(); }
    function setAnim(v) { expandAnim = expandAnims.includes(v) ? v : "spring"; save(); }
    function setCc(v) { ccLayout = ccLayouts.includes(v) ? v : "grid"; save(); }

    function reset() { pillStyle = "notch"; expandAnim = "spring"; ccLayout = "grid"; save(); }
    function setWeather(place, lat, lon) { weatherPlace = place; weatherLat = lat; weatherLon = lon; save(); }

    readonly property string summary: pillStyle + " - " + expandAnim + " - " + ccLayout

    readonly property int morphDurW: expandAnim === "unfold" ? 300 : (expandAnim === "liquid" ? 620 : 520)
    readonly property int morphDurH: expandAnim === "unfold" ? 320 : (expandAnim === "liquid" ? 620 : 520)
    readonly property int morphDelayW: expandAnim === "unfold" ? 120 : 0
    readonly property var morphCurve: expandAnim === "spring" ? [0.34, 1.42, 0.5, 1, 1, 1] : (expandAnim === "liquid" ? [0.65, 0, 0.25, 1, 1, 1] : [0.2, 0.9, 0.2, 1, 1, 1])

    FileView {
        id: file
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/notch.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: root.save()
    }

    function apply(txt) {
        try {
            const j = JSON.parse(txt);
            setPill(j.pillStyle ?? "notch");
            setAnim(j.expandAnim ?? "spring");
            setCc(j.ccLayout ?? "grid");
            setWeather(j.weatherPlace ?? "", j.weatherLat ?? 0, j.weatherLon ?? 0);
        } catch (e) {
            reset();
        }
    }

    property bool _ready: false
    Component.onCompleted: _ready = true
    function save() {
        if (!_ready)
            return;
        file.setText(JSON.stringify({
            pillStyle: pillStyle,
            expandAnim: expandAnim,
            ccLayout: ccLayout,
            weatherPlace: weatherPlace,
            weatherLat: weatherLat,
            weatherLon: weatherLon
        }, null, 2));
    }
}
