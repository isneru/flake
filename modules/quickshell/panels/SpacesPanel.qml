import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/singletons"

Item {
    id: root

    readonly property var focusedMon: Hyprland.focusedMonitor

    readonly property int cols: 3
    readonly property int slots: 10

    readonly property real pad: 10
    readonly property real headerH: 19
    readonly property real gap: 8
    readonly property real cardW: (flick.width - (root.cols - 1) * grid.columnSpacing) / root.cols
    readonly property real viewH: 2 * cardH + grid.rowSpacing
    readonly property real monAspect: {
        const m = root.focusedMon?.lastIpcObject;
        const s = m?.scale ?? 1;
        return ((m?.width ?? 1920) / s) / ((m?.height ?? 1080) / s);
    }
    readonly property real cardH: 2 * pad + headerH + gap + (cardW - 2 * pad) / monAspect

    property var dragging: null
    property int dropWs: 0
    property string dropWin: ""
    property point dropPoint: Qt.point(0, 0)

    function wsFor(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function addrOf(t) {
        return t?.lastIpcObject?.address ?? "";
    }

    function focusWindow(addr) {
        if (addr)
            Hyprland.dispatch(`hl.dsp.focus{ window = "address:${addr}" }`);
    }

    function moveToWorkspace(addr, wsId) {
        const back = Hyprland.focusedWorkspace?.id ?? 0;
        Hyprland.dispatch(`hl.dsp.window.move{ workspace = ${wsId}, window = "address:${addr}" }`);
        if (back && back !== wsId)
            Hyprland.dispatch(`hl.dsp.focus{ workspace = ${back} }`);
    }

    function swapWindows(srcAddr, dstAddr) {
        const backWin = root.addrOf(Hyprland.toplevels.values.find(t => t.activated));
        const backWs = Hyprland.focusedWorkspace?.id ?? 0;
        root.focusWindow(srcAddr);
        Hyprland.dispatch(`hl.dsp.window.swap{ target = "address:${dstAddr}" }`);
        if (backWin && backWin !== srcAddr)
            root.focusWindow(backWin);
        else if (backWs)
            Hyprland.dispatch(`hl.dsp.focus{ workspace = ${backWs} }`);
    }

    function resolveDrop(scenePos) {
        const p = grid.mapFromItem(null, scenePos.x, scenePos.y);
        const card = grid.childAt(p.x, p.y);
        if (!card || !card.screenItem) {
            root.dropWs = 0;
            root.dropWin = "";
            return;
        }
        root.dropWs = card.wsId;
        const q = card.screenItem.mapFromItem(grid, p.x, p.y);
        const hit = card.screenItem.childAt(q.x, q.y);
        const addr = hit && hit.isWindow ? root.addrOf(hit.modelData) : "";
        root.dropWin = addr === root.addrOf(root.dragging) ? "" : addr;
    }

    function restoreCursor() {
        const m = root.focusedMon?.lastIpcObject;
        const gx = Math.round((m?.x ?? 0) + root.dropPoint.x);
        const gy = Math.round((m?.y ?? 0) + root.dropPoint.y);
        Hyprland.dispatch(`hl.dsp.cursor.move{ x = ${gx}, y = ${gy} }`);
    }

    function commitDrop() {
        const addr = root.addrOf(root.dragging);
        const srcWs = root.dragging?.workspace?.id ?? 0;
        let acted = false;
        if (addr && root.dropWs) {
            if (root.dropWin) {
                root.swapWindows(addr, root.dropWin);
                acted = true;
            } else if (root.dropWs !== srcWs) {
                root.moveToWorkspace(addr, root.dropWs);
                acted = true;
            }
        }
        if (acted) {
            root.restoreCursor();
            settle.restart();
        }
        root.dragging = null;
        root.dropWs = 0;
        root.dropWin = "";
    }

    Timer {
        id: settle
        interval: 160
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }

    Component.onCompleted: Hyprland.refreshToplevels()
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen"].includes(event.name))
                Hyprland.refreshToplevels();
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: flick.bottom
        anchors.topMargin: 9
        visible: flick.contentHeight > flick.height + 1
        text: flick.atYEnd ? "scroll up for 1-6" : "scroll for 7-" + root.slots
        font.family: Theme.mono
        font.pixelSize: 10
        color: Theme.t4
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.min(grid.implicitHeight, root.viewH)
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        GridLayout {
            id: grid
            width: flick.width
            columns: root.cols
            rowSpacing: 11
            columnSpacing: 11

            Repeater {
                model: root.slots

                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var ws: root.wsFor(wsId)
                    readonly property bool active: ws?.focused ?? false
                    readonly property var wins: ws?.toplevels?.values ?? []
                    readonly property bool dropTarget: root.dragging !== null && root.dropWs === wsId && root.dropWin === ""
                    property var screenItem: null

                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: root.cardH
                    radius: Theme.rCard
                    color: dropTarget ? Theme.s4 : (active ? Theme.s3 : Theme.s1)
                    border.width: active || dropTarget ? 1 : 0
                    border.color: dropTarget ? Theme.alpha(Theme.accent, 0.6) : Theme.accent
                    Behavior on color { ColorAnimation { duration: 200 } }

                    HoverHandler { id: cardHover }
                    TapHandler {
                        onTapped: {
                            Hyprland.dispatch(Hyprland.usingLua
                                ? "hl.dsp.focus({ workspace = " + card.wsId + " })"
                                : "workspace " + card.wsId);

                            NotchState.close();
                        }
                    }

                    readonly property string layoutName: {
                        if (!ws)
                            return "";
                        if (ws.hasFullscreen)
                            return "fullscreen";
                        return ws.lastIpcObject?.tiledLayout ?? "";
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.pad
                        spacing: root.gap

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: root.headerH
                                Layout.preferredHeight: root.headerH
                                radius: 6
                                color: card.active ? Theme.accent : Theme.s2
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: card.wsId
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: card.active ? Theme.fgOnAccent : Theme.t2
                                }
                            }
                            Text {
                                readonly property string wsName: card.ws?.name ?? ""
                                text: card.wins.length ? (wsName === String(card.wsId) ? "" : wsName) : "empty"
                                font.family: Theme.ui
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: card.wins.length ? Theme.t1 : Theme.t3
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: card.layoutName
                                font.family: Theme.mono
                                font.pixelSize: 10
                                color: Theme.t4
                            }
                        }

                        Item {
                            id: screen
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Component.onCompleted: card.screenItem = screen

                            readonly property var mon: (card.ws?.monitor ?? root.focusedMon)?.lastIpcObject ?? null
                            readonly property real scale: mon?.scale ?? 1
                            readonly property real mw: (mon?.width ?? 1920) / scale
                            readonly property real mh: (mon?.height ?? 1080) / scale
                            readonly property real k: Math.min(width / mw, height / mh)
                            readonly property real ox: (width - mw * k) / 2
                            readonly property real oy: Math.max(0, height - mh * k)

                            Repeater {
                                model: card.wins.slice().sort((a, b) => (a.lastIpcObject?.floating ? 1 : 0) - (b.lastIpcObject?.floating ? 1 : 0))

                                delegate: Rectangle {
                                    id: win
                                    required property var modelData
                                    readonly property var geo: modelData.lastIpcObject
                                    readonly property bool focused: (geo?.focusHistoryID ?? -1) === 0

                                    x: screen.ox + ((geo?.at?.[0] ?? 0) - (screen.mon?.x ?? 0)) * screen.k
                                    y: screen.oy + ((geo?.at?.[1] ?? 0) - (screen.mon?.y ?? 0)) * screen.k
                                    width: Math.max(6, (geo?.size?.[0] ?? 0) * screen.k)
                                    height: Math.max(6, (geo?.size?.[1] ?? 0) * screen.k)

                                    readonly property bool isWindow: true
                                    readonly property bool beingDragged: root.dragging === modelData
                                    readonly property bool swapTarget: root.dropWin !== "" && root.dropWin === root.addrOf(modelData)

                                    radius: 5
                                    color: Theme.notchGlass
                                    opacity: beingDragged ? 0.4 : 1
                                    scale: swapTarget ? 1.06 : 1
                                    z: beingDragged ? 2 : (geo?.floating ?? false) ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                    Behavior on scale { NumberAnimation { duration: 120 } }

                                    HoverHandler { id: winHover }
                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: {
                                            root.focusWindow(root.addrOf(win.modelData));
                                            NotchState.close();
                                        }
                                    }
                                    DragHandler {
                                        id: winDrag
                                        target: null
                                        onActiveChanged: {
                                            if (active) {
                                                root.dragging = win.modelData;
                                            } else if (root.dragging === win.modelData) {
                                                root.commitDrop();
                                            }
                                        }
                                        onCentroidChanged: {
                                            if (active) {
                                                root.dropPoint = centroid.scenePosition;
                                                root.resolveDrop(centroid.scenePosition);
                                            }
                                        }
                                    }

                                    onWidthChanged: recapture.restart()
                                    onHeightChanged: recapture.restart()
                                    Timer {
                                        id: recapture
                                        interval: 250
                                        repeat: false
                                        onTriggered: cap.captureFrame()
                                    }

                                    Item {
                                        id: shot
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true

                                        ScreencopyView {
                                            id: cap
                                            anchors.fill: parent
                                            captureSource: win.modelData.wayland
                                            live: false
                                        }
                                    }
                                    Rectangle {
                                        id: shotMask
                                        anchors.fill: shot
                                        radius: win.radius
                                        color: "black"
                                        visible: false
                                        layer.enabled: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: win.radius
                                        color: "transparent"
                                        border.width: 1
                                        border.color: win.swapTarget || win.focused ? Theme.accent : (winHover.hovered ? Theme.alpha(Theme.t1, 0.45) : ((win.geo?.floating ?? false) ? Theme.alpha(Theme.t1, 0.22) : Theme.hairline))
                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                        z: 3
                                    }
                                    MultiEffect {
                                        anchors.fill: shot
                                        source: shot
                                        maskEnabled: true
                                        maskSource: shotMask
                                        maskThresholdMin: 0.5
                                        visible: cap.hasContent
                                    }

                                    Image {
                                        id: fallbackIcon
                                        anchors.centerIn: parent
                                        visible: !cap.hasContent && status === Image.Ready
                                        source: Quickshell.iconPath(win.geo?.class ?? "", true)
                                        sourceSize.width: 32
                                        sourceSize.height: 32
                                        width: Math.min(24, parent.width * 0.45)
                                        height: width
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !cap.hasContent && !fallbackIcon.visible && win.width >= 44
                                        text: win.geo?.class ?? ""
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                        color: Theme.t3
                                        elide: Text.ElideRight
                                        width: parent.width - 10
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        z: 10
        onWheel: wheel => {
            const max = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = Math.max(0, Math.min(max, flick.contentY - wheel.angleDelta.y));
        }
    }
}
