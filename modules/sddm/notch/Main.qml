import QtQuick

Rectangle {
    id: root

    color: "black"

    readonly property color accent: config.stringValue("accent") || "#7fa8f5"
    readonly property color errorColor: config.stringValue("error") || "#ee7268"
    readonly property color warning: config.stringValue("warning") || "#e0a45e"
    readonly property bool light: config.stringValue("scheme") === "light"

    readonly property color notchSolid: "#050608"
    readonly property color notchGlass: "#0b0c10"

    readonly property int pillW: 196
    readonly property int pillH: 34
    readonly property int pillR: 18

    readonly property int bezelRadius: 20

    readonly property var liquid: [0.65, 0, 0.25, 1, 1, 1]
    readonly property int widthDur: 340
    readonly property int heightDur: 300
    readonly property int overlap: 240

    property real intro: 0
    property real wp: 0
    property real hp: 0
    property real q: 0
    readonly property real rT: Math.max(0, 1 - hp)

    ParallelAnimation {
        id: openAnim
        onFinished: faceIn.start()

        NumberAnimation {
            target: root
            property: "wp"
            to: 1
            duration: root.widthDur
            easing.type: Easing.Bezier
            easing.bezierCurve: root.liquid
        }
        SequentialAnimation {
            PauseAnimation {
                duration: root.overlap
            }
            NumberAnimation {
                target: root
                property: "hp"
                to: 1
                duration: root.heightDur
                easing.type: Easing.InQuart
            }
        }
    }

    NumberAnimation {
        id: faceIn
        target: root
        property: "q"
        to: 1
        duration: 200
        easing.type: Easing.Bezier
        easing.bezierCurve: root.liquid
        onFinished: face.focusField()
    }

    NumberAnimation {
        id: introAnim
        target: root
        property: "intro"
        to: 1
        duration: 250
        onFinished: hold.start()
    }

    Timer {
        id: hold
        interval: 280
        onTriggered: openAnim.start()
    }

    property bool started: false

    function begin() {
        if (started)
            return;
        started = true;
        introAnim.start();
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.begin()
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

    Image {
        id: backdrop
        anchors.fill: parent
        source: "file:///var/lib/sddm-theme/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: root.intro
        onStatusChanged: if (status === Image.Ready)
            root.begin()
    }

    Rectangle {
        id: plate

        opacity: root.intro

        width: root.pillW + (root.width - root.pillW) * root.wp
        height: root.pillH + (root.height - root.pillH) * root.hp
        x: (root.width - width) / 2
        y: 0

        bottomLeftRadius: root.pillR * root.rT
        bottomRightRadius: root.pillR * root.rT

        color: root.hp < 0.5 ? root.notchSolid : (root.light ? "#f4f4f5" : root.notchGlass)

        LockFace {
            id: face
            anchors.fill: parent
            visible: root.q > 0.01
            progress: root.q

            accent: root.accent
            errorColor: root.errorColor
            warning: root.warning
            light: root.light

            wallpaper: "/var/lib/sddm-theme/wallpaper.png"
            user: userModel.lastUser

            showPower: true
            canPowerOff: sddm.canPowerOff
            canReboot: sddm.canReboot
            canSuspend: sddm.canSuspend

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
        }
    }

    Repeater {
        model: [
            {
                atTop: true,
                atLeft: true
            },
            {
                atTop: true,
                atLeft: false
            },
            {
                atTop: false,
                atLeft: true
            },
            {
                atTop: false,
                atLeft: false
            }
        ]
        delegate: Canvas {
            id: wedge
            required property var modelData

            width: root.bezelRadius
            height: root.bezelRadius
            x: modelData.atLeft ? 0 : root.width - width
            y: modelData.atTop ? 0 : root.height - height

            readonly property real cx: modelData.atLeft ? width : 0
            readonly property real cy: modelData.atTop ? height : 0

            onPaint: {
                const ctx = getContext("2d");
                ctx.globalCompositeOperation = "source-over";
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "#000000";
                ctx.fillRect(0, 0, width, height);

                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(cx, cy, width, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }
}
