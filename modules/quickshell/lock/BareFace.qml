import QtQuick
import "root:/singletons"

Rectangle {
    id: root

    signal submitted(string password)

    property string user: ""
    property string wallpaper: ""
    property int battery: -1
    property bool charging: false
    property string networkLabel: ""
    property bool busy: false
    property string status: ""
    property string hint: ""

    function focusField(): void {
        field.forceActiveFocus();
    }

    function clearField(): void {
        field.text = "";
    }

    property date now: new Date()

    readonly property color batteryFg: {
        if (root.battery < 0)
            return Theme.fgMuted;
        if (root.charging)
            return Theme.ansiGreen;
        if (root.battery <= 15)
            return Theme.ansiRed;
        if (root.battery <= 30)
            return Theme.ansiYellow;
        return Theme.fg;
    }

    color: Theme.bg

    Image {
        anchors.fill: parent
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.6)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 32)
        spacing: 8

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: Theme.fg
            font.family: Theme.themeMono
            font.pixelSize: Theme.themeSize * 4
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(root.now, "dddd d MMMM yyyy")
            color: Theme.fgMuted
            font.family: Theme.themeMono
            font.pixelSize: Mode.barFont
            renderType: Text.NativeRendering
        }

        Item {
            width: 1
            height: 24
        }

        Rectangle {
            width: parent.width
            height: field.implicitHeight + 12
            radius: 0
            color: Theme.alpha(Theme.bgDim, 0.94)
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.border

            Text {
                id: prompt
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.user + ": "
                color: Theme.fgMuted
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize
                renderType: Text.NativeRendering
            }

            TextInput {
                id: field
                anchors.left: prompt.right
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.busy
                echoMode: TextInput.Password
                passwordCharacter: "*"
                color: Theme.fg
                font.family: Theme.themeMono
                font.pixelSize: Theme.themeSize
                renderType: Text.NativeRendering
                onAccepted: if (text !== "") root.submitted(text)
                Keys.onEscapePressed: text = ""
            }
        }

        Text {
            width: parent.width
            text: root.status || (root.busy ? "checking" : "[Enter] unlock")
            color: root.status ? Theme.ansiRed : Theme.fgMuted
            font.family: Theme.themeMono
            font.pixelSize: Mode.barFont
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: root.hint
            visible: text !== ""
            wrapMode: Text.Wrap
            color: Theme.ansiYellow
            font.family: Theme.themeMono
            font.pixelSize: Mode.barFont
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Mode.barHeight
        color: Theme.alpha(Theme.bgDim, 0.88)

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.border
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "[locked]"
            color: Theme.accent
            font.family: Theme.themeMono
            font.pixelSize: Mode.barFont
            renderType: Text.NativeRendering
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Text {
                text: root.battery < 0 ? "no batt" : `${root.charging ? "+" : ""}${root.battery}%`
                color: root.batteryFg
                font.family: Theme.themeMono
                font.pixelSize: Mode.barFont
                renderType: Text.NativeRendering
            }

            Text {
                text: root.networkLabel || "offline"
                color: root.networkLabel ? Theme.fg : Theme.fgMuted
                font.family: Theme.themeMono
                font.pixelSize: Mode.barFont
                renderType: Text.NativeRendering
            }
        }
    }
}
