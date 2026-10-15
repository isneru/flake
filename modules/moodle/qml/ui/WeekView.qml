import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"
import "root:/store"

Item {
    id: root

    property int offset: 0

    readonly property double monday: {
        const d = new Date(Moodle.now);
        d.setHours(0, 0, 0, 0);
        d.setDate(d.getDate() - (d.getDay() + 6) % 7 + root.offset * 7);
        return d.getTime();
    }
    readonly property var lectures: Moodle.classes.filter(c => c.start >= root.monday && c.start < root.dayStart(7))
    readonly property int dayCount: root.lectures.some(c => c.start >= root.dayStart(5)) ? 7 : 5
    readonly property int firstHour: Math.min(8, ...root.lectures.map(c => new Date(c.start).getHours()))
    readonly property int lastHour: Math.max(19, ...root.lectures.map(c => Math.ceil(root.hourOf(c.end))))

    function step(n: int): void {
        root.offset += n;
    }

    function dayStart(n: int): double {
        const d = new Date(root.monday);
        d.setDate(d.getDate() + n);
        return d.getTime();
    }

    function lanes(list): var {
        const out = [];
        let group = [];
        let groupEnd = 0;
        const close = () => group.forEach(item => item.lanes = Math.max(...group.map(g => g.lane)) + 1);
        for (const c of list) {
            if (c.start >= groupEnd) {
                close();
                group = [];
            }
            const taken = group.filter(g => g.end > c.start).map(g => g.lane);
            let lane = 0;
            while (taken.includes(lane))
                lane++;
            const item = Object.assign({}, c, { lane: lane, lanes: 1 });
            group.push(item);
            out.push(item);
            groupEnd = Math.max(groupEnd, c.end);
        }
        close();
        return out;
    }

    function hourOf(ms: double): real {
        const d = new Date(ms);
        return d.getHours() + d.getMinutes() / 60;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Week"
                font.family: Style.family
                font.pixelSize: Style.title
                font.weight: Font.DemiBold
                color: Style.text
            }

            Chip {
                text: `${Qt.formatDateTime(new Date(root.monday), "d MMM")} - ${Qt.formatDateTime(new Date(root.dayStart(root.dayCount - 1)), "d MMM")}`
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                glyph: "chevron_left"
                onActivated: root.offset -= 1
            }

            IconButton {
                glyph: "today"
                active: root.offset === 0
                onActivated: root.offset = 0
            }

            IconButton {
                glyph: "chevron_right"
                onActivated: root.offset += 1
            }
        }

        Item {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property int gutter: 40
            readonly property int header: 26
            readonly property real colW: (width - gutter) / root.dayCount
            readonly property real hourH: (height - header) / (root.lastHour - root.firstHour)

            Repeater {
                model: root.lastHour - root.firstHour + 1

                delegate: Item {
                    required property int index

                    y: grid.header + index * grid.hourH
                    width: grid.width

                    Text {
                        anchors.verticalCenter: parent.top
                        text: String(root.firstHour + index).padStart(2, "0") + ":00"
                        font.family: Style.monoFamily
                        font.pixelSize: Style.tiny
                        color: Style.faint
                    }

                    Rectangle {
                        x: grid.gutter
                        width: parent.width - grid.gutter
                        height: 1
                        color: Theme.alpha(Theme.border, 0.6)
                    }
                }
            }

            Repeater {
                model: root.dayCount

                delegate: Item {
                    id: day

                    required property int index
                    readonly property double start: root.dayStart(index)
                    readonly property bool today: Moodle.now >= day.start && Moodle.now < root.dayStart(index + 1)

                    x: grid.gutter + index * grid.colW
                    width: grid.colW
                    height: grid.height

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: grid.header
                        visible: day.today
                        color: Theme.alpha(Theme.accent, 0.05)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: grid.header
                        verticalAlignment: Text.AlignVCenter
                        text: Qt.formatDateTime(new Date(day.start), "ddd d")
                        font.family: Style.family
                        font.pixelSize: Style.small
                        font.weight: day.today ? Font.DemiBold : Font.Medium
                        color: day.today ? Theme.accent : Style.muted
                    }

                    Rectangle {
                        visible: day.today && root.hourOf(Moodle.now) >= root.firstHour && root.hourOf(Moodle.now) <= root.lastHour
                        y: grid.header + (root.hourOf(Moodle.now) - root.firstHour) * grid.hourH
                        width: parent.width
                        height: 2
                        z: 2
                        color: Theme.error
                    }

                    Repeater {
                        model: root.lanes(root.lectures.filter(c => c.start >= day.start && c.start < root.dayStart(day.index + 1)))

                        delegate: Rectangle {
                            id: block

                            required property var modelData
                            readonly property bool linked: block.modelData.courseId !== 0
                            readonly property bool live: block.modelData.start <= Moodle.now && block.modelData.end > Moodle.now
                            readonly property bool over: block.modelData.end <= Moodle.now
                            readonly property color tint: block.live ? Theme.success : (block.over ? Style.muted : Theme.accent)

                            readonly property real laneW: (day.width - 6) / block.modelData.lanes

                            x: 3 + block.modelData.lane * block.laneW
                            y: grid.header + (root.hourOf(block.modelData.start) - root.firstHour) * grid.hourH + 2
                            width: block.laneW - (block.modelData.lane < block.modelData.lanes - 1 ? 3 : 0)
                            height: Math.max(18, (block.modelData.end - block.modelData.start) / 3600000 * grid.hourH - 4)
                            radius: Style.r(Theme.rRow)
                            clip: true
                            opacity: block.over ? 0.6 : 1
                            color: Theme.alpha(block.tint, hover.hovered && block.linked ? 0.3 : 0.18)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }

                            HoverHandler {
                                id: hover
                                cursorShape: block.linked ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }

                            TapHandler {
                                enabled: block.linked
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: Moodle.select(block.modelData.courseId)
                            }

                            Hint {
                                enabled: block.linked
                                onActivated: Moodle.select(block.modelData.courseId)
                            }

                            Rectangle {
                                width: 3
                                height: parent.height
                                color: block.tint
                            }

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 6
                                anchors.topMargin: 5
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: `${block.modelData.code} · ${block.modelData.kind}`
                                    elide: Text.ElideRight
                                    font.family: Style.family
                                    font.pixelSize: Style.body
                                    font.weight: Font.DemiBold
                                    color: Style.text
                                }

                                Text {
                                    width: parent.width
                                    text: [block.modelData.room, block.modelData.teacher].filter(s => s).join(" · ")
                                    elide: Text.ElideRight
                                    font.family: Style.family
                                    font.pixelSize: Style.small
                                    color: Style.dim
                                }

                                Text {
                                    width: parent.width
                                    text: Moodle.span(block.modelData)
                                    elide: Text.ElideRight
                                    font.family: Style.family
                                    font.pixelSize: Style.tiny
                                    color: Style.faint
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
