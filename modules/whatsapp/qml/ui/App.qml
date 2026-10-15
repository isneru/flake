import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/store"

Item {
    id: root

    property string prefix: ""
    property var hints: []
    property string typed: ""

    Keys.onPressed: event => {
        event.accepted = root.hints.length ? root.pick(event) : root.command(event);
    }

    function command(event): bool {
        const prefix = root.prefix;
        root.prefix = "";
        if (event.modifiers & Qt.ControlModifier) {
            switch (event.key) {
            case Qt.Key_D:
                root.scroll(root.height / 2);
                return true;
            case Qt.Key_U:
                root.scroll(-root.height / 2);
                return true;
            }
            return false;
        }
        if (event.key === Qt.Key_Escape) {
            if (Chats.reply)
                Chats.reply = null;
            else
                Chats.query = "";
            return true;
        }
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && Chats.chat) {
            chat.write();
            return true;
        }
        if (!event.text) {
            root.prefix = prefix;
            return false;
        }
        switch (prefix + event.text) {
        case "/":
            sidebar.focusSearch();
            return true;
        case "i":
        case "a":
            if (Chats.chat)
                chat.write();
            return true;
        case "j":
            root.scroll(60);
            return true;
        case "k":
            root.scroll(-60);
            return true;
        case "gg":
            chat.list.stick = false;
            chat.list.positionViewAtBeginning();
            return true;
        case "G":
            chat.list.positionViewAtEnd();
            return true;
        case "J":
        case "K":
            root.cycle(event.text === "J" ? 1 : -1);
            return true;
        case "r":
            root.showHints("reply");
            return true;
        case "s":
            root.showHints("save");
            return true;
        case "o":
            Chats.pick();
            return true;
        case "p":
            if (Chats.chat)
                Chats.paste();
            return true;
        case "g":
            root.prefix = event.text;
            return true;
        }
        return false;
    }

    function scroll(dy: real): void {
        const view = chat.list;
        const span = view.contentHeight - view.height;
        if (span <= 0)
            return;
        const lo = view.originY;
        if (dy < 0)
            view.stick = false;
        view.contentY = Math.max(lo, Math.min(lo + span, view.contentY + dy));
        Qt.callLater(() => view.returnToBounds());
    }

    property string action: ""

    function showHints(action: string): void {
        const view = chat.list;
        if (!Chats.chat || !view.visible)
            return;
        const top = view.mapToItem(root, 0, 0).y;
        const bottom = top + view.height;
        const found = [];
        for (const item of view.contentItem.children) {
            if (item.key === undefined || !item.visible || item.deleted || (action === "save" && !item.media))
                continue;
            const box = item.box;
            const p = box.mapToItem(root, 0, 0);
            if (p.y + box.height <= top || p.y >= bottom)
                continue;
            found.push({
                target: item,
                x: item.me ? p.x + box.width - 20 : p.x,
                y: Math.max(p.y, top)
            });
        }
        found.sort((a, b) => a.y - b.y);
        const width = String(found.length - 1).length;
        found.forEach((h, i) => h.label = found.length <= 9 ? String(i + 1) : String(i).padStart(width, "0"));
        root.typed = "";
        root.action = action;
        root.hints = found;
    }

    function pick(event): bool {
        if (event.key === Qt.Key_Escape) {
            root.hints = [];
        } else if (event.key === Qt.Key_Backspace) {
            root.typed = root.typed.slice(0, -1);
        } else if (/^[0-9]$/.test(event.text)) {
            const typed = root.typed + event.text;
            const left = root.hints.filter(h => h.label.startsWith(typed));
            if (left.length === 1 && left[0].label === typed) {
                root.hints = [];
                if (left[0].target)
                    left[0].target[root.action]();
            } else if (left.length === 0) {
                root.hints = [];
            } else {
                root.typed = typed;
            }
        }
        return true;
    }

    function cycle(n: int): void {
        const shown = Chats.shown;
        if (!shown.length)
            return;
        const i = shown.findIndex(c => c.jid === Chats.jid);
        const next = i < 0 ? (n > 0 ? 0 : shown.length - 1) : (i + n + shown.length) % shown.length;
        Chats.select(shown[next].jid);
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            onDone: root.forceActiveFocus()
            onPicked: chat.write()
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.border
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg

            ChatView {
                id: chat
                anchors.fill: parent
                onLeave: root.forceActiveFocus()
            }
        }
    }

    Repeater {
        model: root.hints

        delegate: Rectangle {
            id: tag

            required property var modelData

            visible: tag.modelData.label.startsWith(root.typed)
            x: tag.modelData.x
            y: tag.modelData.y
            z: 100
            width: label.implicitWidth + 8
            height: label.implicitHeight + 2
            radius: Style.r(3)
            color: Theme.accent
            border.color: Theme.border
            border.width: 1

            Row {
                id: label
                anchors.centerIn: parent

                Text {
                    text: root.typed
                    font.family: Style.monoFamily
                    font.pixelSize: Style.small
                    font.weight: Font.DemiBold
                    color: Theme.bgDim
                }

                Text {
                    text: tag.modelData.label.slice(root.typed.length)
                    font.family: Style.monoFamily
                    font.pixelSize: Style.small
                    font.weight: Font.DemiBold
                    color: Theme.bg
                }
            }
        }
    }
}
