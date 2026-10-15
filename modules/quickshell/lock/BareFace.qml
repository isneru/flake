import QtQuick

Rectangle {
    id: root

    signal submitted(string password)
    signal powerRequested(string action)

    property string user: ""
    property string wallpaper: ""
    property int battery: -1
    property bool charging: false
    property string networkLabel: ""
    property bool busy: false
    property string status: ""
    property string hint: ""

    property string tag: "[locked]"
    property string verb: "unlock"
    property bool showPower: false
    property bool canSuspend: false
    property bool canReboot: false
    property bool canPowerOff: false

    property color bg: "#11121a"
    property color bgDim: "#0d0e14"
    property color borderColor: "#2a2b3a"
    property color fg: "#c8ccd8"
    property color fgMuted: "#5a5f70"
    property color accent: "#7fa8f5"
    property color red: "#ee7268"
    property color green: "#4ec79b"
    property color yellow: "#e0a45e"
    property string mono: "monospace"
    property int size: 18
    property int small: 16
    property int cornerRadius: 0
    property bool solid: false

    function focusField(): void {
        field.forceActiveFocus();
    }

    function clearField(): void {
        field.text = "";
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, root.solid ? 1 : a);
    }

    property date now: new Date()

    readonly property color batteryFg: {
        if (root.battery < 0)
            return root.fgMuted;
        if (root.charging)
            return root.green;
        if (root.battery <= 15)
            return root.red;
        if (root.battery <= 30)
            return root.yellow;
        return root.fg;
    }

    color: root.bg

    Image {
        anchors.fill: parent
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.6)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    readonly property int margin: 72

    Text {
        x: root.margin
        y: 92
        text: root.tag
        color: root.accent
        font.family: root.mono
        font.pixelSize: root.small
        renderType: Text.NativeRendering
    }

    Row {
        x: root.margin
        y: 116
        spacing: 16

        Text {
            visible: !root.showPower
            text: root.battery < 0 ? "no batt" : `${root.charging ? "+" : ""}${root.battery}%`
            color: root.batteryFg
            font.family: root.mono
            font.pixelSize: root.small
            renderType: Text.NativeRendering
        }

        Text {
            visible: !root.showPower
            text: root.networkLabel || "offline"
            color: root.networkLabel ? root.fg : root.fgMuted
            font.family: root.mono
            font.pixelSize: root.small
            renderType: Text.NativeRendering
        }

        Repeater {
            model: root.showPower ? [
                { key: "suspend", on: root.canSuspend },
                { key: "reboot", on: root.canReboot },
                { key: "poweroff", on: root.canPowerOff }
            ].filter(a => a.on) : []

            Text {
                required property var modelData
                text: `[${modelData.key}]`
                color: power.containsMouse ? root.accent : root.fg
                font.family: root.mono
                font.pixelSize: root.small
                renderType: Text.NativeRendering

                MouseArea {
                    id: power
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.powerRequested(parent.modelData.key)
                }
            }
        }
    }

    Text {
        x: root.margin
        y: 210
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: root.fg
        font.family: root.mono
        font.pixelSize: root.size * 8
        renderType: Text.NativeRendering
    }

    Text {
        x: root.margin
        y: 420
        text: Qt.formatDateTime(root.now, "dddd d MMMM yyyy")
        color: root.fgMuted
        font.family: root.mono
        font.pixelSize: root.small
        renderType: Text.NativeRendering
    }

    Text {
        x: root.margin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 168
        text: root.user + ":"
        color: root.fgMuted
        font.family: root.mono
        font.pixelSize: root.size
        renderType: Text.NativeRendering
    }

    Rectangle {
        x: root.margin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 108
        width: Math.min(300, parent.width - 2 * root.margin)
        height: 44
        radius: root.cornerRadius
        color: root.alpha(root.bgDim, 0.94)
        border.width: 1
        border.color: field.activeFocus ? root.accent : root.borderColor

        TextInput {
            id: field
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.verticalCenter: parent.verticalCenter
            enabled: !root.busy
            echoMode: TextInput.Password
            passwordCharacter: "*"
            color: root.fg
            font.family: root.mono
            font.pixelSize: root.size
            renderType: Text.NativeRendering
            onAccepted: if (text !== "") root.submitted(text)
            Keys.onEscapePressed: text = ""
        }
    }

    Text {
        id: statusLine
        x: root.margin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64
        width: Math.min(300, parent.width - 2 * root.margin)
        text: root.status || (root.busy ? "checking" : "[Enter] " + root.verb)
        color: root.status ? root.red : root.fgMuted
        font.family: root.mono
        font.pixelSize: root.small
        renderType: Text.NativeRendering
    }

    Text {
        x: root.margin
        anchors.top: statusLine.bottom
        anchors.topMargin: 4
        width: parent.width - 2 * root.margin
        text: root.hint
        visible: text !== ""
        wrapMode: Text.Wrap
        color: root.yellow
        font.family: root.mono
        font.pixelSize: root.small
        renderType: Text.NativeRendering
    }
}
