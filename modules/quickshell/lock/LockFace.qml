import QtQuick
import QtQuick.Effects

Item {
    id: root

    property color accent: "#7fa8f5"
    property color errorColor: "#ee7268"
    property color warning: "#e0a45e"
    property bool light: false

    property string uiFont: "DM Sans"
    property string monoFont: "JetBrains Mono"
    property string iconFont: "Material Symbols Rounded"

    property string wallpaper: ""
    property string user: "user"

    property bool busy: false
    property string status: ""
    property string hint: ""

    property real progress: 0

    property int battery: -1
    property bool charging: false
    property string networkLabel: ""
    property bool networkWired: false

    property bool showPower: false
    property bool canPowerOff: false
    property bool canReboot: false
    property bool canSuspend: false

    signal submitted(string password)
    signal powerRequested(string action)

    function focusField() {
        field.forceActiveFocus();
    }
    function clearField() {
        field.text = "";
    }

    readonly property real cT: Math.max(0, Math.min(1, progress))

    readonly property real ink: light ? 0 : 1
    readonly property color glass: light ? "#f4f4f5" : "#0b0c10"
    readonly property color s1: Qt.rgba(ink, ink, ink, 0.045)
    readonly property color s2: Qt.rgba(ink, ink, ink, 0.06)
    readonly property color s4: Qt.rgba(ink, ink, ink, 0.13)
    readonly property color hairline: Qt.rgba(ink, ink, ink, light ? 0.16 : 0.09)
    readonly property color t1: light ? "#0f0f0f" : "#ffffff"
    readonly property color t2: Qt.rgba(ink, ink, ink, light ? 0.72 : 0.60)
    readonly property color t3: Qt.rgba(ink, ink, ink, light ? 0.58 : 0.42)
    readonly property color t4: Qt.rgba(ink, ink, ink, light ? 0.42 : 0.30)

    onStatusChanged: if (status) shakeAnim.restart()

    function submit() {
        if (busy || field.text.length === 0)
            return;
        root.submitted(field.text);
    }

    Image {
        id: paper
        anchors.fill: parent
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
    }

    MultiEffect {
        anchors.fill: paper
        source: paper
        visible: paper.status === Image.Ready
        opacity: root.cT
        blurEnabled: true
        blur: 1.0
        blurMax: 28
        autoPaddingEnabled: false
        brightness: root.light ? 0.28 : -0.28
        saturation: -0.15
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(1 - root.ink, 1 - root.ink, 1 - root.ink, 0.35)
        opacity: root.cT
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 1 - 0.16 * root.cT)
    }

    Item {
        anchors.fill: parent
        opacity: root.cT
        visible: opacity > 0.01

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            spacing: 18

            Row {
                spacing: 7
                visible: root.battery >= 0
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    filled: true
                    family: root.iconFont
                    text: root.charging ? "battery_charging_full" : "battery_std"
                    color: root.t3
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.battery + "%"
                    font.family: root.monoFont
                    font.pixelSize: 12
                    color: root.t3
                }
            }

            Row {
                spacing: 7
                visible: root.networkLabel !== ""
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    filled: true
                    family: root.iconFont
                    text: root.networkWired ? "lan" : "wifi"
                    color: root.t3
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.networkLabel
                    font.family: root.uiFont
                    font.pixelSize: 12
                    color: root.t3
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.height * 0.18) + Math.round((1 - root.cT) * 18)
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: root.monoFont
                font.pixelSize: 116
                font.weight: Font.Medium
                font.letterSpacing: 2
                color: root.t1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                font.family: root.uiFont
                font.pixelSize: 17
                color: root.t3
            }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round(parent.height * 0.16) + Math.round((1 - root.cT) * 18)
            spacing: 16

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                radius: 32
                color: root.s2
                border.width: 1
                border.color: root.hairline

                Text {
                    anchors.centerIn: parent
                    text: root.user.charAt(0).toUpperCase()
                    font.family: root.uiFont
                    font.pixelSize: 26
                    font.weight: Font.Medium
                    color: root.t1
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.user
                font.family: root.uiFont
                font.pixelSize: 14
                font.weight: Font.Medium
                color: root.t2
            }

            Rectangle {
                id: box
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 46
                radius: 23
                color: root.s1
                border.width: 1
                border.color: root.status ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.6) : (field.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6) : root.hairline)
                Behavior on border.color {
                    ColorAnimation {
                        duration: 200
                    }
                }

                Glyph {
                    id: lockGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 17
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    family: root.iconFont
                    text: root.busy ? "hourglass_top" : "lock"
                    color: root.t3
                }

                TextInput {
                    id: field
                    anchors.left: lockGlyph.right
                    anchors.leftMargin: 13
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !root.busy
                    echoMode: TextInput.Password
                    passwordCharacter: "*"
                    font.family: root.uiFont
                    font.pixelSize: 15
                    color: root.t1
                    selectionColor: root.accent
                    clip: true
                    onTextChanged: root.status = ""
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text.length === 0 && !root.busy
                        text: "Password"
                        font: field.font
                        color: root.t4
                    }
                }

                SequentialAnimation {
                    id: shakeAnim
                    running: false
                    NumberAnimation {
                        target: box
                        property: "anchors.horizontalCenterOffset"
                        to: -9
                        duration: 45
                    }
                    NumberAnimation {
                        target: box
                        property: "anchors.horizontalCenterOffset"
                        to: 9
                        duration: 90
                    }
                    NumberAnimation {
                        target: box
                        property: "anchors.horizontalCenterOffset"
                        to: -6
                        duration: 90
                    }
                    NumberAnimation {
                        target: box
                        property: "anchors.horizontalCenterOffset"
                        to: 0
                        duration: 45
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 16
                text: root.busy ? "checking…" : root.status
                font.family: root.uiFont
                font.pixelSize: 12
                color: root.status ? root.errorColor : root.t3
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.hint !== ""
                text: root.hint
                font.family: root.monoFont
                font.pixelSize: 11
                color: root.warning
            }
        }

        Row {
            visible: root.showPower
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 32
            spacing: 10

            Repeater {
                model: [
                    {
                        icon: "bedtime",
                        action: "suspend",
                        show: root.canSuspend
                    },
                    {
                        icon: "restart_alt",
                        action: "reboot",
                        show: root.canReboot
                    },
                    {
                        icon: "power_settings_new",
                        action: "poweroff",
                        show: root.canPowerOff
                    }
                ]
                delegate: Rectangle {
                    id: btn
                    required property var modelData

                    visible: modelData.show
                    width: 30
                    height: 30
                    radius: 15
                    color: hover.hovered ? root.s4 : root.s2
                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }

                    Glyph {
                        anchors.centerIn: parent
                        size: 17
                        family: root.iconFont
                        text: btn.modelData.icon
                        color: Qt.rgba(root.ink, root.ink, root.ink, 0.8)
                    }

                    HoverHandler {
                        id: hover
                    }
                    TapHandler {
                        onTapped: root.powerRequested(btn.modelData.action)
                    }
                }
            }
        }
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: date = new Date()
    }
}
