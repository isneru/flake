import QtQuick
import QtQuick.Shapes
import "root:/singletons"

Item {
    id: root

    property string edge: "top"
    property string corner: ""

    property real fillet: 14
    property real cornerRadius: Theme.rCollapsed
    property color tint: Theme.notchGlass
    property bool pinned: false

    readonly property bool floating: NotchState.floating
    readonly property real inset: NotchState.topMargin

    property var window: null

    property real joinGap: fillet * 2

    property real joinStart: 0.85
    property int joinDur: 180

    property real hitLength: openLength
    property real hitDepth: 18

    property real openLength: 0
    property real openDepth: 0

    property alias content: body.data

    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool cornered: corner !== ""
    readonly property bool hovered: hitHover.hovered || bodyHover.hovered
    readonly property bool open: hovered || pinned

    readonly property real length: openLength
    property real depth: open ? openDepth : 0

    Behavior on depth {
        NumberAnimation { duration: Config.morphDurH; easing.type: Easing.Bezier; easing.bezierCurve: Config.morphCurve }
    }

    readonly property real cornerPad: cornered && floating ? Math.max(fillet, inset) : fillet
    readonly property real uSpan: length + cornerPad + (cornered ? 0 : fillet)
    readonly property real uOff: cornered && floating ? cornerPad - inset - fillet : 0
    readonly property real vSpan: depth + inset + (cornered && !floating ? fillet : 0)

    readonly property var uMaxSide: ({ top: "right", bottom: "left", left: "top", right: "bottom" })
    readonly property bool flip: cornered && corner !== uMaxSide[edge]
    function fu(u) {
        return flip ? uSpan - u : u;
    }
    readonly property int arcFlare: flip ? PathArc.Counterclockwise : PathArc.Clockwise
    readonly property int arcRound: flip ? PathArc.Clockwise : PathArc.Counterclockwise

    readonly property real openRatio: openDepth > 0 ? Math.max(0, Math.min(1, depth / openDepth)) : 0

    readonly property string screenName: window?.screen?.name ?? ""

    readonly property real winU: {
        if (!window || !window.screen)
            return 0;
        const s = window.screen, a = window.anchors, m = window.margins;
        if (vertical)
            return a.top ? m.top : (a.bottom ? s.height - window.height - m.bottom : (s.height - window.height) / 2);
        return a.left ? m.left : (a.right ? s.width - window.width - m.right : (s.width - window.width) / 2);
    }

    readonly property real uMin: winU + (vertical ? y + frame.y + body.y : x + frame.x + body.x)
    readonly property real uMax: uMin + length

    readonly property bool uReversed: (edge === "bottom" || edge === "left") !== flip

    function joinFor(atMax) {
        if (floating)
            return { ready: false, e: 0 };
        const mine = atMax ? uMax : uMin;
        const list = EdgeTabs.tabs;
        for (let i = 0; i < list.length; i++) {
            const n = list[i];
            if (n === root || n.edge !== edge || n.screenName !== screenName)
                continue;
            if (n.openDepth !== openDepth || String(n.tint) !== String(tint))
                continue;
            if (!pinned && !n.pinned)
                continue;
            const gap = atMax ? n.uMin - mine : mine - n.uMax;
            if (gap < 0 || gap > joinGap)
                continue;
            return {
                ready: openRatio >= joinStart && n.openRatio >= joinStart,
                e: Math.min(gap / 2, fillet)
            };
        }
        return { ready: false, e: 0 };
    }

    readonly property var joinA: joinFor(uReversed)
    readonly property var joinB: cornered ? ({ ready: false, e: 0 }) : joinFor(!uReversed)

    property real jA: joinA.ready ? 1 : 0
    property real jB: joinB.ready ? 1 : 0
    Behavior on jA { NumberAnimation { duration: root.joinDur; easing.type: Easing.OutCubic } }
    Behavior on jB { NumberAnimation { duration: root.joinDur; easing.type: Easing.OutCubic } }

    Component.onCompleted: EdgeTabs.register(root)
    Component.onDestruction: EdgeTabs.unregister(root)

    function px(u, v) {
        switch (edge) {
        case "bottom":
            return uSpan - fu(u);
        case "left":
            return v;
        case "right":
            return vSpan - v;
        default:
            return fu(u);
        }
    }
    function py(u, v) {
        switch (edge) {
        case "bottom":
            return vSpan - v;
        case "left":
            return uSpan - fu(u);
        case "right":
            return fu(u);
        default:
            return v;
        }
    }

    implicitWidth: vertical ? Math.max(vSpan, hitDepth) : Math.max(uSpan, hitLength)
    implicitHeight: vertical ? Math.max(uSpan, hitLength) : Math.max(vSpan, hitDepth)
    width: implicitWidth
    height: implicitHeight

    Item {
        id: hit
        x: root.edge === "right" ? root.width - root.hitDepth : 0
        y: root.edge === "bottom" ? root.height - root.hitDepth : 0
        width: root.vertical ? root.hitDepth : root.width
        height: root.vertical ? root.height : root.hitDepth
        HoverHandler { id: hitHover }
    }

    Item {
        id: frame
        width: root.vertical ? root.vSpan : root.uSpan
        height: root.vertical ? root.uSpan : root.vSpan

        x: root.vertical ? (root.edge === "right" ? root.width - width : 0) : (root.cornered ? (root.corner === "right" ? root.width - width : 0) : (root.width - width) / 2)
        y: root.vertical ? (root.cornered ? (root.corner === "bottom" ? root.height - height : 0) : (root.height - height) / 2) : (root.edge === "bottom" ? root.height - height : 0)

        Shape {
            id: sh
            anchors.fill: parent
            visible: root.depth > 0.5 && !root.floating
            preferredRendererType: Shape.CurveRenderer

            readonly property real d: root.depth
            readonly property real len: root.length
            readonly property real f: root.fillet
            readonly property real rb: Math.max(0, Math.min(root.cornerRadius, d / 2, len / 2))
            readonly property real re: Math.max(0, Math.min(f, d - rb))
            readonly property real rp: Math.max(0, Math.min(f, len - rb))
            readonly property real br: Math.max(0, Math.min(Bezel.radius, len - rp, d))
            readonly property real ov: root.cornered ? 1 : 0

            readonly property real eA: root.jA * root.joinA.e
            readonly property real eB: root.jB * root.joinB.e
            readonly property real reA: sh.re * (1 - root.jA)
            readonly property real reB: sh.re * (1 - root.jB)
            readonly property real rbA: sh.rb * (1 - root.jA)
            readonly property real rbB: sh.rb * (1 - root.jB)
            readonly property real uFar: sh.f + sh.len + sh.ov + sh.eB

            ShapePath {
                fillColor: root.tint
                strokeColor: "transparent"

                startX: root.px(sh.f - sh.eA - sh.reA, 0)
                startY: root.py(sh.f - sh.eA - sh.reA, 0)

                PathArc {
                    x: root.px(sh.f - sh.eA, sh.reA); y: root.py(sh.f - sh.eA, sh.reA)
                    radiusX: sh.reA; radiusY: sh.reA
                    direction: root.arcFlare
                }
                PathLine { x: root.px(sh.f - sh.eA, sh.d - sh.rbA); y: root.py(sh.f - sh.eA, sh.d - sh.rbA) }
                PathArc {
                    x: root.px(sh.f - sh.eA + sh.rbA, sh.d); y: root.py(sh.f - sh.eA + sh.rbA, sh.d)
                    radiusX: sh.rbA; radiusY: sh.rbA
                    direction: root.arcRound
                }

                PathLine {
                    x: root.px(sh.uFar - (root.cornered ? sh.rp : sh.rbB), sh.d)
                    y: root.py(sh.uFar - (root.cornered ? sh.rp : sh.rbB), sh.d)
                }
                PathArc {
                    x: root.px(sh.uFar, sh.d + (root.cornered ? sh.rp : -sh.rbB))
                    y: root.py(sh.uFar, sh.d + (root.cornered ? sh.rp : -sh.rbB))
                    radiusX: root.cornered ? sh.rp : sh.rbB
                    radiusY: root.cornered ? sh.rp : sh.rbB
                    direction: root.cornered ? root.arcFlare : root.arcRound
                }
                PathLine {
                    x: root.px(sh.uFar, root.cornered ? sh.br - sh.ov : sh.reB)
                    y: root.py(sh.uFar, root.cornered ? sh.br - sh.ov : sh.reB)
                }
                PathArc {
                    x: root.px(sh.uFar + (root.cornered ? -sh.br : sh.reB), -sh.ov)
                    y: root.py(sh.uFar + (root.cornered ? -sh.br : sh.reB), -sh.ov)
                    radiusX: root.cornered ? sh.br : sh.reB
                    radiusY: root.cornered ? sh.br : sh.reB
                    direction: root.cornered ? root.arcRound : root.arcFlare
                }
            }
        }

        Rectangle {
            anchors.fill: body
            visible: root.floating && root.depth > 0.5
            radius: Math.min(root.cornerRadius, width / 2, height / 2)
            color: root.tint
        }

        Item {
            id: body
            readonly property real u0: root.fillet + root.uOff
            readonly property real ax: root.px(u0, root.inset)
            readonly property real ay: root.py(u0, root.inset)
            readonly property real bx: root.px(u0 + root.length, root.inset + root.depth)
            readonly property real by: root.py(u0 + root.length, root.inset + root.depth)

            x: Math.min(ax, bx)
            y: Math.min(ay, by)
            width: Math.abs(bx - ax)
            height: Math.abs(by - ay)
            clip: true
            HoverHandler { id: bodyHover }
        }
    }
}
