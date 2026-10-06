import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    property string query: ""
    property int selected: 0

    readonly property bool webOnly: query.trim().startsWith("?")
    readonly property string webQuery: webOnly ? query.trim().slice(1).trim() : query.trim()
    readonly property bool hasWeb: !calcOnly && webQuery.length > 0

    readonly property bool calcOnly: query.trim().startsWith("=")
    readonly property string calcExpr: calcOnly ? query.trim().slice(1).trim() : query.trim()
    readonly property bool wantsCalc: calcExpr !== "" && !webOnly && (calcOnly || /\d/.test(calcExpr))
    property string calcAsked: ""
    property string calcFor: ""
    property string calcResult: ""
    property bool calcPending: false
    readonly property bool hasCalc: wantsCalc && calcResult !== "" && calcResult.replace(/\s/g, "") !== calcFor.replace(/\s/g, "")

    readonly property int calcIndex: apps.length
    readonly property int webIndex: apps.length + (hasCalc ? 1 : 0)
    readonly property bool calcSelected: hasCalc && selected === calcIndex
    readonly property bool webSelected: hasWeb && selected === webIndex
    readonly property int maxIndex: webIndex - 1 + (hasWeb ? 1 : 0)

    readonly property var apps: {
        if (root.webOnly || root.calcOnly)
            return [];
        const all = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const q = query.trim().toLowerCase();
        if (!q)
            return all.sort((a, b) => root.used(b) - root.used(a) || a.name.localeCompare(b.name)).slice(0, 40);
        const hits = [];
        for (const a of all) {
            const s = root.score(a, q);
            if (s > 0)
                hits.push({ app: a, s: s });
        }
        hits.sort((x, y) => (y.s - x.s) || (root.used(y.app) - root.used(x.app)) || x.app.name.localeCompare(y.app.name));
        return hits.slice(0, 40).map(h => h.app);
    }

    function used(a) {
        return Usage.count(a.id);
    }

    function score(a, q) {
        const name = (a.name ?? "").toLowerCase();
        const desc = ((a.comment || a.genericName) ?? "").toLowerCase();
        if (name.startsWith(q))
            return 100;
        if (name.includes(q))
            return 70;
        if (desc.includes(q))
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

    function launch(a) {
        if (!a)
            return;
        Usage.bump(a.id);
        const cmd = a.command;
        if (a.runInTerminal)
            Quickshell.execDetached(["kitty", "-e"].concat(cmd));
        else
            Quickshell.execDetached(cmd);
        NotchState.close();
    }

    function searchWeb() {
        if (!hasWeb)
            return;
        Quickshell.execDetached(["qutebrowser", webQuery]);
        NotchState.close();
    }

    function evaluate() {
        if (!wantsCalc) {
            calcFor = "";
            calcResult = "";
            calcPending = false;
            return;
        }
        if (calc.running || calcExpr === calcFor)
            return;
        calcAsked = calcExpr;
        calc.running = true;
    }

    function copyCalc() {
        Quickshell.execDetached(["wl-copy", "--", calcResult]);
        NotchState.close();
    }

    function accept() {
        if (calcSelected) {
            if (calcFor === calcExpr)
                copyCalc();
            else
                calcPending = true;
        } else if (webSelected)
            searchWeb();
        else
            launch(apps[selected]);
    }

    onQueryChanged: {
        selected = 0;
        evaluate();
    }

    Process {
        id: calc
        command: ["qalc", "-t", root.calcAsked]
        stdout: StdioCollector {
            onStreamFinished: {
                root.calcResult = text.trim().replace(/\s*\n\s*/g, " ");
                root.calcFor = root.calcAsked;
                if (root.calcPending && root.calcFor === root.calcExpr) {
                    root.calcPending = false;
                    root.copyCalc();
                } else
                    root.evaluate();
            }
        }
    }

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

            Icon { size: 19; text: "search"; color: Theme.t2 }
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
                Component.onCompleted: {
                    if (NotchState.panel === "calc") {
                        text = "=";
                        cursorPosition = 1;
                    }
                    forceActiveFocus();
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Search apps, ? to search the web, = to calculate"
                    font: input.font
                    color: Theme.t4
                }

                Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.maxIndex)
                Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
                Keys.onReturnPressed: root.accept()
                Keys.onEnterPressed: root.accept()
                Keys.onTabPressed: if (root.apps[root.selected]) input.text = root.apps[root.selected].name
            }
            Text {
                text: "SUPER+D"
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
        model: root.apps
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
                    root.launch(row.modelData);
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
                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        size: 17
                        text: "apps"
                        color: Theme.t3
                        visible: !appIcon.visible
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
                        text: row.modelData.comment || row.modelData.genericName || ""
                        font.family: Theme.ui
                        font.pixelSize: 11
                        color: Theme.t3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                Text {
                    text: row.modelData.runInTerminal ? "term" : "app"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                }
            }
        }
    }

    Rectangle {
        visible: root.hasCalc
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Layout.fillHeight: false
        radius: 12
        color: root.calcSelected ? Theme.s4 : (calcHover.hovered ? Theme.s2 : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        HoverHandler { id: calcHover }
        TapHandler {
            onTapped: {
                root.selected = root.calcIndex;
                root.accept();
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
                    text: "calculate"
                    color: Theme.t3
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "= " + root.calcResult
                    font.family: Theme.mono
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.t1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.calcFor
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.t3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Text {
                text: "copy"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }
    }

    Rectangle {
        visible: root.hasWeb
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Layout.fillHeight: false
        radius: 12
        color: root.webSelected ? Theme.s4 : (webHover.hovered ? Theme.s2 : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        HoverHandler { id: webHover }
        TapHandler {
            onTapped: {
                root.selected = root.webIndex;
                root.searchWeb();
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
                    text: "travel_explore"
                    color: Theme.t3
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Search the web"
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.t1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.webQuery
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.t3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Text {
                text: "web"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: false
        text: "↑↓ select - ↵ launch - ? web - = calc - TAB complete - ESC close"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
