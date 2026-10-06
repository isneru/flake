import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    property string query: ""
    property int selected: 0

    readonly property var src: Picks.source

    readonly property var hits: {
        const all = Picks.items;
        const q = root.query.trim().toLowerCase();
        if (!q)
            return all;
        const scored = [];
        for (const it of all) {
            const s = root.score(it, q);
            if (s > 0)
                scored.push({ it: it, s: s });
        }
        scored.sort((a, b) => (b.s - a.s) || a.it.name.localeCompare(b.it.name));
        return scored.map(o => o.it);
    }
    readonly property int maxIndex: hits.length - 1

    function score(it, q) {
        const name = (it.name ?? "").toLowerCase();
        const sub = (it.sub ?? "").toLowerCase();
        if (name.startsWith(q))
            return 100;
        if (name.includes(q))
            return 70;
        if (sub.includes(q))
            return 40;
        return root.subsequence(name, q) ? 20 : 0;
    }
    function subsequence(hay, q) {
        let i = 0;
        for (const c of hay)
            if (c === q[i] && ++i === q.length)
                return true;
        return false;
    }

    function accept() {
        const it = root.hits[root.selected];
        if (it)
            Picks.accept(it.key);
    }

    onQueryChanged: selected = 0

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 46
        Layout.fillHeight: false
        radius: 13
        color: Theme.s1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 12

            Icon { size: 19; text: root.src?.icon ?? "search"; color: Theme.t2 }
            TextInput {
                id: input
                Layout.fillWidth: true
                font.family: Theme.ui
                font.pixelSize: 14
                color: Theme.t1
                selectionColor: Theme.accent
                clip: true
                focus: true
                onTextChanged: root.query = text
                Component.onCompleted: forceActiveFocus()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: root.src?.hint ?? ""
                    font: input.font
                    color: Theme.t4
                }

                Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.maxIndex)
                Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
                Keys.onReturnPressed: root.accept()
                Keys.onEnterPressed: root.accept()
                Keys.onTabPressed: if (root.hits[root.selected]) input.text = root.hits[root.selected].name
            }
            Text {
                text: Picks.active
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: root.hits
        currentIndex: root.selected
        highlightFollowsCurrentItem: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool active: root.selected === index

            width: ListView.view.width
            height: 48
            radius: 12
            color: active ? Theme.s4 : (rowHover.hovered ? Theme.s2 : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
            HoverHandler { id: rowHover }
            TapHandler {
                onTapped: {
                    root.selected = row.index;
                    Picks.accept(row.modelData.key);
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 9
                    color: Theme.s2
                    Icon {
                        anchors.centerIn: parent
                        size: 17
                        text: row.modelData.icon || root.src?.icon || "chevron_right"
                        color: Theme.t3
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: row.modelData.name
                        font.family: Theme.ui
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.t1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: text !== ""
                        text: row.modelData.sub ?? ""
                        font.family: Theme.ui
                        font.pixelSize: 11
                        color: Theme.t3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                Text {
                    visible: text !== ""
                    text: row.modelData.tag ?? ""
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                }
            }
        }
    }

    Text {
        visible: root.hits.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: false
        text: Picks.loading ? "Loading…" : (root.query.trim() ? "No match" : (root.src?.empty ?? "Nothing to pick"))
        font.family: Theme.ui
        font.pixelSize: 12
        color: Theme.t4
    }

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: false
        text: "↑↓ select - ↵ open - TAB complete - ESC close"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
