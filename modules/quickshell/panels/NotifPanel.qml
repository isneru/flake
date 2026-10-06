import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 30
        spacing: 10

        Rectangle {
            readonly property bool on: NotchState.toggles.dnd
            Layout.preferredWidth: dndRow.implicitWidth + 26
            Layout.preferredHeight: 30
            radius: 15
            color: on ? Theme.warning : (dndHover.hovered ? Theme.s3 : Theme.s2)
            Behavior on color { ColorAnimation { duration: 200 } }
            HoverHandler { id: dndHover }
            TapHandler { onTapped: NotchState.toggle("dnd") }

            Row {
                id: dndRow
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 17
                    filled: true
                    text: "do_not_disturb_on"
                    color: parent.parent.on ? Theme.fgOnAccent : Theme.t2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Do not disturb"
                    font.family: Theme.ui
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: parent.parent.on ? Theme.fgOnAccent : Qt.rgba(1, 1, 1, 0.9)
                }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            Layout.preferredWidth: clearLabel.implicitWidth + 26
            Layout.preferredHeight: 30
            radius: 15
            color: clearHover.hovered ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 200 } }
            opacity: Notifs.count > 0 ? 1 : 0.4
            HoverHandler { id: clearHover }
            TapHandler {
                enabled: Notifs.count > 0
                onTapped: Notifs.clearAll()
            }
            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                font.family: Theme.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Notifs.count > 0
        clip: true
        spacing: 10
        model: Notifs.groups
        boundsBehavior: Flickable.StopAtBounds

        delegate: Column {
            id: grp
            required property var modelData
            readonly property var items: modelData.items
            readonly property bool stacked: items.length > 1
            readonly property bool open: Notifs.isOpen(modelData)
            width: ListView.view.width
            spacing: 0

            Repeater {
                model: grp.items

                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property bool shown: grp.open || index === 0
                    readonly property bool head: index === 0 && grp.stacked && !grp.open
                    readonly property int pad: (grp.open && index < grp.items.length - 1) ? 8 : 0
                    property int deck: !head ? 0 : (grp.items.length > 2 ? 12 : 6)
                    width: grp.width
                    height: shown ? note.height + deck + pad : 0
                    opacity: shown ? 1 : 0
                    visible: height > 0
                    clip: true

                    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on deck { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: note.height
                        width: note.width - 16
                        height: Math.min(6, slot.deck)
                        clip: true
                        Rectangle {
                            y: -14
                            width: parent.width
                            height: 20
                            radius: 14
                            color: Theme.s3
                        }
                    }
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: note.height + 6
                        width: note.width - 32
                        height: Math.max(0, Math.min(6, slot.deck - 6))
                        clip: true
                        Rectangle {
                            y: -14
                            width: parent.width
                            height: 20
                            radius: 14
                            color: Theme.s2
                        }
                    }

                    Rectangle {
                        id: note
                        readonly property var modelData: slot.modelData
                        readonly property var defaultAction: Notifs.defaultAction(modelData)
                        width: parent.width
                        height: card.implicitHeight + 26
                        radius: 14
                        color: rowHover.hovered ? Theme.s2 : Theme.s1
                        Behavior on color { ColorAnimation { duration: 140 } }

                        HoverHandler { id: rowHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                if (slot.head)
                                    Notifs.toggleGroup(grp.modelData);
                                else
                                    Notifs.invokeAction(note.modelData, note.defaultAction);
                            }
                        }

                        ColumnLayout {
                            id: card
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 13
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignTop
                                    radius: 10
                                    color: Theme.s2

                                    Image {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        width: 19
                                        height: 19
                                        source: {
                                            const n = note.modelData;
                                            if (n.image)
                                                return n.image;
                                            return n.appIcon ? Quickshell.iconPath(n.appIcon, true) : "";
                                        }
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }
                                    Icon {
                                        anchors.centerIn: parent
                                        size: 18
                                        text: note.modelData.icon || "notifications"
                                        color: Theme.accent
                                        visible: !appIcon.visible
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text {
                                            text: note.modelData.summary
                                            font.family: Theme.ui
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: Theme.t1
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 380
                                        }
                                        Text {
                                            readonly property string ago: Notifs.ago(note.modelData.time)
                                            readonly property int repeats: note.modelData.count ?? 1
                                            readonly property int grouped: slot.head ? grp.items.length : 0
                                            text: note.modelData.app + (ago ? " - " + ago : "") + (repeats > 1 ? " - ×" + repeats : "") + (grouped ? " - " + grouped + " notifications" : "")
                                            font.family: Theme.ui
                                            font.pixelSize: 11
                                            color: Theme.t3
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        visible: text !== ""
                                        text: note.modelData.body
                                        font.family: Theme.ui
                                        font.pixelSize: 12
                                        color: Theme.t2
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            Row {
                                Layout.leftMargin: 44
                                Layout.topMargin: 2
                                spacing: 8

                                Repeater {
                                    model: Notifs.buttons(note.modelData)
                                    delegate: Rectangle {
                                        id: action
                                        required property var modelData
                                        height: 26
                                        width: actionLabel.implicitWidth + 24
                                        radius: 8
                                        color: aHover.hovered ? Theme.s4 : Theme.s3
                                        HoverHandler { id: aHover }
                                        TapHandler {
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onTapped: Notifs.invokeAction(note.modelData, action.modelData)
                                        }
                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: action.modelData.text
                                            font.family: Theme.ui
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Qt.rgba(1, 1, 1, 0.9)
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 26
                                    width: dismissLabel.implicitWidth + 24
                                    radius: 8
                                    color: dHover.hovered ? Theme.s3 : Qt.rgba(1, 1, 1, 0.04)
                                    HoverHandler { id: dHover }
                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: slot.head ? Notifs.dismissGroup(grp.modelData) : Notifs.dismiss(note.modelData)
                                    }
                                    Text {
                                        id: dismissLabel
                                        anchors.centerIn: parent
                                        text: slot.head ? "Clear all" : "Dismiss"
                                        font.family: Theme.ui
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Theme.t2
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: grp.width
                height: grp.open ? 34 : 0
                visible: height > 0
                clip: true
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Row {
                    x: 14
                    y: 8
                    spacing: 8

                    Rectangle {
                        height: 26
                        width: lessRow.implicitWidth + 24
                        radius: 8
                        color: lessHover.hovered ? Theme.s3 : Qt.rgba(1, 1, 1, 0.04)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: lessHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: Notifs.toggleGroup(grp.modelData)
                        }

                        Row {
                            id: lessRow
                            anchors.centerIn: parent
                            spacing: 5

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 14
                                text: "expand_less"
                                color: Theme.t2
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Show less"
                                font.family: Theme.ui
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.t2
                            }
                        }
                    }

                    Rectangle {
                        height: 26
                        width: clearGroupLabel.implicitWidth + 24
                        radius: 8
                        color: clearGroupHover.hovered ? Theme.s3 : Qt.rgba(1, 1, 1, 0.04)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: clearGroupHover }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: Notifs.dismissGroup(grp.modelData)
                        }
                        Text {
                            id: clearGroupLabel
                            anchors.centerIn: parent
                            text: "Clear all"
                            font.family: Theme.ui
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.t2
                        }
                    }
                }
            }
        }
    }

    Item {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        Column {
            anchors.centerIn: parent
            spacing: 10
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 32
                text: "notifications_off"
                color: Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t3
            }
        }
    }
}
