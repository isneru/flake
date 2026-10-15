pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    readonly property int minTemp: 2500
    readonly property int maxTemp: 6000
    readonly property int stepK: 100

    readonly property int temperature: Persist.nightTemp
    readonly property bool enabled: Persist.night

    Process { id: daemon }
    Process {
        id: ctl
        onExited: code => {
            if (root.enabled && code !== 0 && !daemon.running) {
                daemon.command = ["hyprsunset", "-t", String(root.temperature)];
                daemon.running = true;
            }
        }
    }

    onEnabledChanged: apply()
    onTemperatureChanged: if (enabled) settle.restart()
    Component.onCompleted: if (enabled) apply()

    Timer {
        id: settle
        interval: 120
        onTriggered: root.apply()
    }

    function setEnabled(on) {
        Persist.setNight(on);
    }

    function setTemperature(k) {
        Persist.setNightTemp(Math.max(root.minTemp, Math.min(root.maxTemp, Math.round(k / root.stepK) * root.stepK)));
    }

    function step(steps) {
        if (root.enabled)
            root.setTemperature(root.temperature + steps * root.stepK);
    }

    function apply() {
        run(enabled ? ["hyprctl", "hyprsunset", "temperature", String(temperature)] : ["hyprctl", "hyprsunset", "identity"]);
    }

    function run(cmd) {
        ctl.running = false;
        ctl.command = cmd;
        ctl.running = true;
    }
}
