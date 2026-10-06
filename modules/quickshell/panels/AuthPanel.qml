import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    property bool remember: false

    Component.onDestruction: Auth.cancelAll()

    Connections {
        target: Auth
        function onPendingChanged() {
            if (!Auth.pending)
                NotchState.close();
        }
        function onAskChanged() {
            root.remember = false;
            field.text = "";
            field.forceActiveFocus();
        }
    }

    function send() {
        if (!Auth.pending)
            return;
        if (Auth.confirming || Auth.displaying) {
            Auth.confirm();
            return;
        }
        Auth.submit(field.text, root.remember);
        field.text = "";
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 24

        Text {
            text: Auth.caption
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.warning
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: Auth.queue.length > 1
            text: "+" + (Auth.queue.length - 1) + " waiting"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.t3
        }
        Text {
            visible: Auth.polkit && !Polkit.registered
            text: "agent not registered"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.error
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.rCard
        color: Theme.s1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 24
            spacing: 20

            Icon {
                Layout.alignment: Qt.AlignVCenter
                size: 44
                filled: true
                text: Auth.icon
                color: Theme.warning
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: Auth.message
                font.family: Theme.ui
                font.pixelSize: 15
                font.weight: Font.Medium
                lineHeight: 1.25
                color: Theme.t1
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.fillHeight: false
        radius: Theme.rRow
        color: Theme.s1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14

            Text {
                text: Auth.detailLabel
                font.family: Theme.ui
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 0.5
                color: Theme.t4
            }
            Text {
                Layout.fillWidth: true
                text: Auth.detail
                font.family: Theme.mono
                font.pixelSize: 12
                color: Theme.t2
                elide: Text.ElideMiddle
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 46
        Layout.fillHeight: false
        visible: !Auth.confirming && !Auth.displaying
        radius: 13
        color: Theme.s1
        border.width: 1
        border.color: Auth.statusIsError ? Theme.alpha(Theme.error, 0.6)
            : (field.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.hairline)
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Icon {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            size: 17
            text: "key"
            color: Theme.t3
        }

        TextInput {
            id: field
            anchors.left: glyph.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            enabled: Auth.inputEnabled
            echoMode: Auth.echo ? TextInput.Normal : TextInput.Password
            passwordCharacter: "*"
            font.family: Theme.ui
            font.pixelSize: 14
            color: Theme.t1
            selectionColor: Theme.accent
            clip: true
            focus: true
            Component.onCompleted: forceActiveFocus()
            Keys.onReturnPressed: root.send()
            Keys.onEnterPressed: root.send()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text.length === 0
                text: Auth.prompt
                font: field.font
                color: Theme.t4
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        Layout.fillHeight: false
        visible: Auth.canRemember

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 6
                color: root.remember ? Theme.accent : "transparent"
                border.width: 1
                border.color: root.remember ? Theme.accent : Theme.hairline
                Behavior on color { ColorAnimation { duration: 160 } }

                Icon {
                    anchors.centerIn: parent
                    size: 13
                    filled: true
                    text: "check"
                    visible: root.remember
                    color: Theme.fgOnAccent
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Remember in the login keyring"
                font.family: Theme.ui
                font.pixelSize: 12
                color: Theme.t2
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.remember = !root.remember
        }
    }

    Item {
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        focus: Auth.confirming || Auth.displaying
        Keys.onReturnPressed: root.send()
        Keys.onEnterPressed: root.send()
        onFocusChanged: if (focus) forceActiveFocus()
    }

    Text {
        Layout.fillWidth: true
        Layout.preferredHeight: 15
        Layout.fillHeight: false
        text: Auth.status
        font.family: Theme.ui
        font.pixelSize: 12
        color: Auth.statusIsError ? Theme.error : Theme.t3
        elide: Text.ElideRight
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        Layout.fillHeight: false
        spacing: 9

        Rectangle {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 44
            radius: 13
            color: cancelArea.containsMouse ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: Auth.denyLabel
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.t1
            }
            MouseArea {
                id: cancelArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Auth.cancel()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 13
            color: Theme.accent
            opacity: okArea.containsMouse ? 0.88 : 1
            Text {
                anchors.centerIn: parent
                text: Auth.confirmLabel
                font.family: Theme.ui
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.fgOnAccent
            }
            MouseArea {
                id: okArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.send()
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: Auth.footer
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
        elide: Text.ElideRight
    }
}
