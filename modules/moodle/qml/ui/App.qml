import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/singletons"
import "root:/store"

Item {
    id: root

    readonly property bool searching: Moodle.query.trim().length >= 2
    readonly property Item page: root.searching ? search : Moodle.courseId !== 0 ? course : Moodle.week ? week : home
    readonly property Flickable list: root.page.list ?? null

    property string prefix: ""
    property var hints: []
    property string typed: ""

    property var back: []
    property var ahead: []
    property var here: ({
            courseId: 0,
            week: false
        })
    property bool traveling: false

    Keys.onPressed: event => {
        event.accepted = root.hints.length ? root.pick(event) : root.command(event);
    }

    Connections {
        target: Moodle
        function onCourseIdChanged(): void {
            Qt.callLater(root.record);
        }
        function onWeekChanged(): void {
            Qt.callLater(root.record);
        }
    }

    function command(event): bool {
        const prefix = root.prefix;
        root.prefix = "";
        if (event.modifiers & Qt.ControlModifier) {
            switch (event.key) {
            case Qt.Key_R:
                Moodle.sync();
                return true;
            case Qt.Key_B:
                Moodle.browse(Moodle.course ? Moodle.course.url : "");
                return true;
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
            if (Moodle.query)
                Moodle.query = "";
            else
                Moodle.courseId = 0;
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
        case "j":
            root.scroll(60);
            return true;
        case "k":
            root.scroll(-60);
            return true;
        case "gg":
            if (root.list)
                root.list.positionViewAtBeginning();
            return true;
        case "G":
            if (root.list)
                root.list.positionViewAtEnd();
            return true;
        case "h":
        case "l":
            if (root.page.step)
                root.page.step(event.text === "l" ? 1 : -1);
            return true;
        case "J":
        case "K":
            root.cycle(event.text === "J" ? 1 : -1);
            return true;
        case "H":
        case "L":
            root.travel(event.text === "L");
            return true;
        case "f":
            root.showHints();
            return true;
        case "n":
            Moodle.newNote();
            return true;
        case "r":
            if (Moodle.courseId)
                Moodle.refresh(Moodle.courseId);
            else
                Moodle.sync();
            return true;
        case "yy":
            if (Moodle.course)
                Quickshell.clipboardText = Moodle.course.url;
            return true;
        case "g":
        case "y":
            root.prefix = event.text;
            return true;
        }
        return false;
    }

    function scroll(dy: real): void {
        const view = root.list;
        const span = view ? view.contentHeight - view.height : 0;
        if (span <= 0)
            return;
        const lo = view.originY;
        view.contentY = Math.max(lo, Math.min(lo + span, view.contentY + dy));
        Qt.callLater(() => view.returnToBounds());
    }

    function cycle(n: int): void {
        const shown = Moodle.shown;
        if (!shown.length)
            return;
        const i = shown.findIndex(c => c.id === Moodle.courseId);
        const next = i < 0 ? (n > 0 ? 0 : shown.length - 1) : (i + n + shown.length) % shown.length;
        Moodle.query = "";
        Moodle.select(shown[next].id);
    }

    function record(): void {
        const now = {
            courseId: Moodle.courseId,
            week: Moodle.week
        };
        if (!root.traveling && (now.courseId !== root.here.courseId || now.week !== root.here.week)) {
            root.back = root.back.concat([root.here]);
            root.ahead = [];
        }
        root.here = now;
        root.traveling = false;
    }

    function travel(forward: bool): void {
        const from = forward ? root.ahead : root.back;
        if (!from.length)
            return;
        const dest = from[from.length - 1];
        if (forward) {
            root.ahead = from.slice(0, -1);
            root.back = root.back.concat([root.here]);
        } else {
            root.back = from.slice(0, -1);
            root.ahead = root.ahead.concat([root.here]);
        }
        root.traveling = true;
        Moodle.query = "";
        Moodle.week = dest.week;
        if (dest.courseId)
            Moodle.select(dest.courseId);
        else
            Moodle.courseId = 0;
    }

    function rectOf(item: Item): var {
        const p = item.mapToItem(root, 0, 0);
        return {
            x: p.x,
            y: p.y,
            w: item.width,
            h: item.height
        };
    }

    function clip(a, b): var {
        const x = Math.max(a.x, b.x);
        const y = Math.max(a.y, b.y);
        return {
            x: x,
            y: y,
            w: Math.min(a.x + a.w, b.x + b.w) - x,
            h: Math.min(a.y + a.h, b.y + b.h) - y
        };
    }

    function showHints(): void {
        const found = [];
        for (const target of Hints.targets) {
            if (!target.visible || !target.enabled)
                continue;
            let r = root.clip(root.rectOf(target), root.rectOf(root));
            for (let a = target.parent; a && a !== root && r.w > 0 && r.h > 0; a = a.parent)
                if (a.clip)
                    r = root.clip(r, root.rectOf(a));
            if (r.w > 0 && r.h > 0)
                found.push({
                    target: target,
                    x: r.x,
                    y: r.y
                });
        }
        found.sort((a, b) => a.y - b.y || a.x - b.x);
        const width = String(found.length - 1).length;
        found.forEach((h, i) => h.label = found.length <= 9 ? String(i + 1) : String(i).padStart(width, "0"));
        root.typed = "";
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
                    left[0].target.activated();
            } else if (left.length === 0) {
                root.hints = [];
            } else {
                root.typed = typed;
            }
        }
        return true;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.preferredWidth: 278
            Layout.fillHeight: true
            onDone: root.forceActiveFocus()
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.border
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            SearchView {
                id: search
                anchors.fill: parent
                visible: root.searching
            }

            Home {
                id: home
                anchors.fill: parent
                visible: !root.searching && Moodle.courseId === 0 && !Moodle.week
            }

            WeekView {
                id: week
                anchors.fill: parent
                visible: !root.searching && Moodle.courseId === 0 && Moodle.week
            }

            CourseView {
                id: course
                anchors.fill: parent
                visible: !root.searching && Moodle.courseId !== 0
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
