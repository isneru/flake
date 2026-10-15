import QtQuick

BareFace {
    id: face

    user: userModel.lastUser
    wallpaper: "/var/lib/sddm-theme/wallpaper.png"
    tag: "[login]"
    verb: "log in"

    showPower: true
    canSuspend: sddm.canSuspend
    canReboot: sddm.canReboot
    canPowerOff: sddm.canPowerOff

    bg: config.stringValue("bg") || "#11121a"
    bgDim: config.stringValue("bgDim") || "#0d0e14"
    borderColor: config.stringValue("border") || "#2a2b3a"
    fg: config.stringValue("fg") || "#c8ccd8"
    fgMuted: config.stringValue("fgMuted") || "#5a5f70"
    accent: config.stringValue("accent") || "#7fa8f5"
    red: config.stringValue("red") || "#ee7268"
    green: config.stringValue("green") || "#4ec79b"
    yellow: config.stringValue("yellow") || "#e0a45e"
    mono: config.stringValue("mono") || "monospace"
    size: parseInt(config.stringValue("size")) || 18
    small: parseInt(config.stringValue("sizeSmall")) || 16

    onSubmitted: password => {
        face.status = "";
        face.busy = true;
        sddm.login(userModel.lastUser, password, sessionModel.lastIndex);
    }

    onPowerRequested: action => {
        if (action === "poweroff")
            sddm.powerOff();
        else if (action === "reboot")
            sddm.reboot();
        else if (action === "suspend")
            sddm.suspend();
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            face.busy = false;
            face.clearField();
            face.status = "wrong password";
            face.focusField();
        }
    }

    Component.onCompleted: focusField()
}
