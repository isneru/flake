import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import "root:/singletons"

Item {
    id: root

    property string pending: ""

    readonly property string hintText: "PAM is not answering — recover from a TTY with Ctrl+Alt+F2"

    function submit(password) {
        if (face.busy)
            return;
        root.pending = password;
        face.clearField();
        face.status = "";
        face.busy = true;
        if (!pam.start()) {
            face.busy = false;
            root.pending = "";
            face.status = "auth unavailable";
            face.hint = root.hintText;
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
            face.busy = false;
            root.pending = "";
            if (result === PamResult.Success) {
                face.status = "";
                Lock.unlock();
                return;
            }
            face.status = result === PamResult.MaxTries ? "too many attempts" : "wrong password";
            face.focusField();
        }

        onError: {
            face.busy = false;
            root.pending = "";
            face.status = "authentication error";
            face.hint = root.hintText;
            face.focusField();
        }
    }

    BareFace {
        id: face
        anchors.fill: parent

        user: Quickshell.env("USER") || "user"
        wallpaper: Lock.wallpaper
        battery: BareState.battery ? Math.round(BareState.battery.percentage * 100) : -1
        charging: BareState.battery?.state === UPowerDeviceState.Charging
        networkLabel: BareState.networkName === "" ? "" : (BareState.wired ? "Wired" : BareState.networkName)

        bg: Theme.bg
        bgDim: Theme.bgDim
        borderColor: Theme.border
        fg: Theme.fg
        fgMuted: Theme.fgMuted
        accent: Theme.accent
        red: Theme.ansiRed
        green: Theme.ansiGreen
        yellow: Theme.ansiYellow
        mono: Theme.themeMono
        size: Theme.themeSize
        small: Mode.barFont
        cornerRadius: Mode.radius
        solid: Mode.soft

        onSubmitted: password => root.submit(password)
        Component.onCompleted: focusField()
    }
}
