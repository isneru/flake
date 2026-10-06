import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 10

    property string query: ""

    readonly property var groups: Bindings.forMode(false)

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        if (!q)
            return groups;
        const out = [];
        for (const g of groups) {
            const items = g.items.filter(i => (i[0] + " " + i[1]).toLowerCase().includes(q));
            if (items.length)
                out.push({ title: g.title, items: items });
        }
        return out;
    }
    readonly property int shown: filtered.reduce((n, g) => n + g.items.length, 0)
    readonly property int total: groups.reduce((n, g) => n + g.items.length, 0)

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        Layout.fillHeight: false
        radius: 12
        color: Theme.s1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 11

            Icon { size: 17; text: "search"; color: Theme.t2 }
            TextInput {
                id: input
                Layout.fillWidth: true
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t1
                selectionColor: Theme.accent
                clip: true
                focus: true
                onTextChanged: root.query = text
                Component.onCompleted: forceActiveFocus()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Filter bindings"
                    font: input.font
                    color: Theme.t4
                }
            }
            Text {
                text: root.shown + " / " + root.total
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }
    }

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.shown > 0
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: body
            width: flick.width
            spacing: 13

            Repeater {
                model: root.filtered

                delegate: ColumnLayout {
                    id: grp
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: grp.modelData.title
                        font.family: Theme.ui
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 0.55
                        color: Theme.t3
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 20

                        Repeater {
                            model: grp.modelData.items

                            delegate: RowLayout {
                                id: row
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                spacing: 10

                                Row {
                                    Layout.preferredWidth: 172
                                    spacing: 4

                                    Repeater {
                                        model: row.modelData[0].split("+")

                                        delegate: Rectangle {
                                            required property string modelData
                                            width: cap.implicitWidth + 15
                                            height: 21
                                            radius: 6
                                            color: Theme.s2
                                            border.width: 1
                                            border.color: Theme.hairline

                                            Text {
                                                id: cap
                                                anchors.centerIn: parent
                                                text: parent.modelData
                                                font.family: Theme.mono
                                                font.pixelSize: 10
                                                color: Theme.t2
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    text: row.modelData[1]
                                    font.family: Theme.ui
                                    font.pixelSize: 12
                                    color: Theme.t2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.shown === 0

        Column {
            anchors.centerIn: parent
            spacing: 8
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 30
                text: "keyboard_off"
                color: Theme.t4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No binding matches"
                font.family: Theme.ui
                font.pixelSize: 13
                color: Theme.t3
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "hyprland.lua - " + root.total + " bindings"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
