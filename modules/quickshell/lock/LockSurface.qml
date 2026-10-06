import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import "root:/singletons"

Item {
    id: root

    property string pending: ""

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string hintText: "PAM is not answering — recover from a TTY with Ctrl+Alt+F2"

    property real q: 0
    readonly property int dur: 200

    readonly property var face: loader.item

    Component.onCompleted: openAnim.start()

    NumberAnimation {
        id: openAnim
        target: root
        property: "q"
        to: 1
        duration: root.dur
        easing.type: Easing.Bezier
        easing.bezierCurve: Lock.liquid
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "q"
        to: 0
        duration: Math.round(root.dur * 0.8)
        easing.type: Easing.Bezier
        easing.bezierCurve: Lock.liquid
        onFinished: Lock.release()
    }

    Connections {
        target: Lock
        function onClosingChanged() {
            if (!Lock.closing)
                return;
            if (Mode.bare) {
                Lock.release();
                return;
            }
            openAnim.stop();
            closeAnim.start();
        }
    }

    PamContext {
        id: pam
        config: "quickshell"
        configDirectory: "/etc/pam.d"

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.pending);
        }

        onCompleted: result => {
            root.face.busy = false;
            root.pending = "";
            if (result === PamResult.Success) {
                root.face.status = "";
                Lock.beginUnlock();
                return;
            }
            root.face.status = result === PamResult.MaxTries ? "too many attempts" : "wrong password";
            root.face.focusField();
        }

        onError: {
            root.face.busy = false;
            root.pending = "";
            root.face.status = "authentication error";
            root.face.hint = root.hintText;
            root.face.focusField();
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: Mode.bare ? bareFace : notchFace
        onLoaded: item.focusField()
    }

    Connections {
        target: loader.item
        function onSubmitted(password): void {
            root.submit(password);
        }
    }

    function submit(password) {
        if (root.face.busy)
            return;
        root.pending = password;
        root.face.clearField();
        root.face.status = "";
        root.face.busy = true;
        if (!pam.start()) {
            root.face.busy = false;
            root.pending = "";
            root.face.status = "auth unavailable";
            root.face.hint = root.hintText;
        }
    }

    readonly property int batteryPct: NotchState.battery ? Math.round(NotchState.battery.percentage * 100) : -1
    readonly property bool charging: NotchState.battery?.state === UPowerDeviceState.Charging
    readonly property string networkLabel: NotchState.networkName === "" ? "" : (NotchState.wired ? "Wired" : NotchState.networkName)

    Component {
        id: notchFace

        LockFace {
            progress: root.q

            accent: Theme.accent
            errorColor: Theme.error
            warning: Theme.warning
            light: Theme.light
            uiFont: Theme.ui
            monoFont: Theme.mono
            iconFont: Theme.icons

            wallpaper: Lock.wallpaper
            user: root.user

            battery: root.batteryPct
            charging: root.charging
            networkLabel: root.networkLabel
            networkWired: NotchState.wired
        }
    }

    Component {
        id: bareFace

        BareFace {
            wallpaper: Lock.wallpaper
            user: root.user
            battery: root.batteryPct
            charging: root.charging
            networkLabel: root.networkLabel
        }
    }
}
