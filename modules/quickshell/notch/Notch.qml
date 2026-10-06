import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/singletons"
import "root:/components"

Scope {
    id: root
    required property var modelData

    PanelWindow {
        id: win
        screen: root.modelData

        anchors { top: true; left: true; right: true; bottom: Lock.active }
        implicitHeight: 540 + NotchState.pad + NotchState.topMargin
        visible: !NotchState.hidden || Lock.active
        color: "transparent"

        exclusiveZone: (NotchState.fullscreen || Lock.active) ? 0 : NotchState.reserved
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notch"

        WlrLayershell.keyboardFocus: NotchState.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        HyprlandFocusGrab {
            windows: [win]
            active: NotchState.isExpanded && !Lock.active && !Screencast.picking
            onCleared: NotchState.close()
        }

        mask: Region { item: Lock.active ? cover : surface }

        IdleInhibitor {
            window: win
            enabled: NotchState.idleInhibit
        }

        Item {
            id: surfaceWrap
            anchors.horizontalCenter: parent.horizontalCenter
            y: NotchState.topMargin
            width: surface.width
            height: surface.height

            readonly property int shadowPad: NotchState.isExpanded ? 140 : 60

            Item {
                id: shadowSrc
                anchors.fill: parent
                anchors.margins: -parent.shadowPad
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: shadowSrc.parent.shadowPad + (NotchState.isExpanded ? 20 : 12)
                    radius: surface.bottomLeftRadius
                    color: "#000000"
                }
            }
            Item {
                id: shadowMask
                anchors.fill: parent
                anchors.margins: -parent.shadowPad
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: shadowMask.parent.shadowPad
                    topLeftRadius: surface.topLeftRadius
                    topRightRadius: surface.topRightRadius
                    bottomLeftRadius: surface.bottomLeftRadius
                    bottomRightRadius: surface.bottomRightRadius
                    color: "#000000"
                }
            }
            MultiEffect {
                anchors.fill: shadowSrc
                source: shadowSrc
                maskEnabled: true
                maskSource: shadowMask
                maskInverted: true
                maskThresholdMin: 0.5
                autoPaddingEnabled: false
                shadowEnabled: !NotchState.split
                shadowColor: Qt.rgba(0, 0, 0, NotchState.isExpanded ? 0.9 : 0.75)
                shadowVerticalOffset: NotchState.isExpanded ? 40 : 14
                shadowHorizontalOffset: 0
                shadowScale: 1.0
                blurMax: NotchState.isExpanded ? 90 : 40
                shadowBlur: 1.0
                opacity: NotchState.split ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 240 } }
            }

            Shape {
                id: outline
                visible: Config.pillStyle === "notch" && !Lock.active
                anchors.fill: surface
                anchors.leftMargin: -r
                anchors.rightMargin: -r
                preferredRendererType: Shape.CurveRenderer

                readonly property real r: 14
                readonly property real w: surface.width
                readonly property real h: surface.height
                readonly property real rb: surface.bottomLeftRadius

                property color fill: NotchState.surfaceColor
                Behavior on fill { ColorAnimation { duration: 400 } }

                property real bw: NotchState.isIdle ? 0 : 1
                Behavior on bw { NumberAnimation { duration: Config.morphDurH } }

                readonly property real so: bw / 2

                readonly property real rbe: Math.max(bw, Math.min(rb, h / 2, w / 2))
                readonly property real re: Math.max(0, Math.min(r, h - rbe))

                readonly property real xr: r + w
                readonly property real lf: r - re
                readonly property real rf: xr + re
                readonly property real kf: Math.sqrt((re + bw) * (re + bw) - re * re)
                readonly property real ks: Math.sqrt((re + so) * (re + so) - re * re)

                ShapePath {
                    fillColor: outline.fill
                    strokeColor: "transparent"

                    startX: outline.lf + outline.kf
                    startY: 0
                    PathArc {
                        x: outline.r + outline.bw; y: outline.re
                        radiusX: outline.re + outline.bw; radiusY: outline.re + outline.bw
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: outline.r + outline.bw; y: outline.h - outline.rbe }
                    PathArc {
                        x: outline.r + outline.rbe; y: outline.h - outline.bw
                        radiusX: outline.rbe - outline.bw; radiusY: outline.rbe - outline.bw
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: outline.xr - outline.rbe; y: outline.h - outline.bw }
                    PathArc {
                        x: outline.xr - outline.bw; y: outline.h - outline.rbe
                        radiusX: outline.rbe - outline.bw; radiusY: outline.rbe - outline.bw
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: outline.xr - outline.bw; y: outline.re }
                    PathArc {
                        x: outline.rf - outline.kf; y: 0
                        radiusX: outline.re + outline.bw; radiusY: outline.re + outline.bw
                        direction: PathArc.Clockwise
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: outline.bw > 0 ? Theme.hairline : "transparent"
                    strokeWidth: outline.bw
                    capStyle: ShapePath.FlatCap

                    startX: outline.lf + outline.ks
                    startY: 0
                    PathArc {
                        x: outline.r + outline.so; y: outline.re
                        radiusX: outline.re + outline.so; radiusY: outline.re + outline.so
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: outline.r + outline.so; y: outline.h - outline.rbe }
                    PathArc {
                        x: outline.r + outline.rbe; y: outline.h - outline.so
                        radiusX: outline.rbe - outline.so; radiusY: outline.rbe - outline.so
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: outline.xr - outline.rbe; y: outline.h - outline.so }
                    PathArc {
                        x: outline.xr - outline.so; y: outline.h - outline.rbe
                        radiusX: outline.rbe - outline.so; radiusY: outline.rbe - outline.so
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: outline.xr - outline.so; y: outline.re }
                    PathArc {
                        x: outline.rf - outline.ks; y: 0
                        radiusX: outline.re + outline.so; radiusY: outline.re + outline.so
                        direction: PathArc.Clockwise
                    }
                }
            }

            Rectangle {
                id: surface
                visible: !Lock.active
                width: NotchState.surfaceW
                height: NotchState.surfaceH
                color: Config.pillStyle === "notch" ? "transparent" : NotchState.surfaceColor
                topLeftRadius: NotchState.radiusTop
                topRightRadius: NotchState.radiusTop
                bottomLeftRadius: NotchState.radiusBottom
                bottomRightRadius: NotchState.radiusBottom
                border.width: NotchState.split || Config.pillStyle === "notch" ? 0 : 1
                border.color: Theme.hairline
                clip: false

                Behavior on width {
                    SequentialAnimation {
                        PauseAnimation { duration: Config.morphDelayW }
                        NumberAnimation {
                            duration: Config.morphDurW
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Config.morphCurve
                        }
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Config.morphDurH
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Config.morphCurve
                    }
                }
                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on topLeftRadius { NumberAnimation { duration: Config.morphDurH } }
                Behavior on topRightRadius { NumberAnimation { duration: Config.morphDurH } }
                Behavior on bottomLeftRadius { NumberAnimation { duration: Config.morphDurH } }
                Behavior on bottomRightRadius { NumberAnimation { duration: Config.morphDurH } }

                HoverHandler {
                    onHoveredChanged: {
                        NotchState.osdHovered = hovered;
                        hovered ? NotchState.peek() : NotchState.unpeek();
                    }
                }

                TapHandler {
                    enabled: !NotchState.isExpanded
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: NotchState.activate()
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: drag => {
                        if (drag.hasUrls)
                            NotchState.dropTarget = true;
                        else
                            drag.accepted = false;
                    }
                    onExited: NotchState.dropTarget = false
                    onDropped: drop => {
                        NotchState.dropTarget = false;
                        if (!drop.hasUrls)
                            return;
                        drop.acceptProposedAction();
                        Shelf.add(drop.urls);
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: NotchState.split
                    sourceComponent: SplitPill {}
                }
                Loader {
                    anchors.fill: parent
                    active: NotchState.isIdle && !NotchState.split && !NotchState.dropTarget
                    sourceComponent: Collapsed {}
                }
                Loader {
                    anchors.fill: parent
                    active: NotchState.isPeek && !NotchState.dropTarget
                    sourceComponent: Peek {}
                }
                Loader {
                    anchors.fill: parent
                    active: NotchState.dropTarget && !NotchState.isExpanded
                    sourceComponent: DropHint {}
                }

                Loader {
                    anchors.fill: parent
                    active: NotchState.isOsd && NotchState.osdKind === "notif" && !NotchState.dropTarget
                    sourceComponent: NotifOsd {}
                }
                Loader {
                    anchors.fill: parent
                    active: NotchState.isOsd && NotchState.osdKind !== "notif" && !NotchState.dropTarget
                    sourceComponent: Osd {}
                }
                Loader {
                    anchors.fill: parent
                    active: NotchState.isExpanded
                    sourceComponent: Expanded {}
                }
            }
        }

        Loader {
            id: cover
            anchors.fill: parent
            active: Lock.active
            sourceComponent: LockCover {}
        }

        Shortcut {
            sequences: ["Escape"]
            enabled: NotchState.isExpanded
            onActivated: NotchState.close()
        }

    }
}
