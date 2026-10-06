import QtQuick
import QtQuick.Layouts
import "root:/singletons"
import "root:/components"

ColumnLayout {
    id: root
    spacing: 12

    property bool picking: !Weather.configured

    Component.onCompleted: if (Weather.configured) Weather.refresh()

    Connections {
        target: Config
        function onWeatherPlaceChanged() { root.picking = false; }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 30
        spacing: 10

        Text {
            text: (Weather.configured && !root.picking) ? Config.weatherPlace.toUpperCase() : "PICK A LOCATION"
            font.family: Theme.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.55
            color: Theme.t3
            elide: Text.ElideRight
            Layout.maximumWidth: 480
        }
        Item { Layout.fillWidth: true }

        Rectangle {
            visible: Weather.configured
            Layout.preferredWidth: changeLabel.implicitWidth + 26
            Layout.preferredHeight: 30
            radius: 15
            color: changeArea.containsMouse ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                id: changeLabel
                anchors.centerIn: parent
                text: root.picking ? "Cancel" : "Change"
                font.family: Theme.ui
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.t1
            }
            MouseArea {
                id: changeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picking = !root.picking
            }
        }

        Rectangle {
            visible: Weather.configured && !root.picking
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: refreshArea.containsMouse ? Theme.s3 : Theme.s2
            Behavior on color { ColorAnimation { duration: 160 } }
            Icon {
                anchors.centerIn: parent
                size: 16
                text: "refresh"
                color: Theme.t2
            }
            MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Weather.refresh()
            }
        }
    }

    Rectangle {
        visible: root.picking
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
                Component.onCompleted: forceActiveFocus()
                onTextChanged: debounce.restart()
                Keys.onReturnPressed: if (Weather.places.length) Weather.pick(Weather.places[0])

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "City name — Porto, Lisbon, Berlin…"
                    font: input.font
                    color: Theme.t4
                }
            }
            Text {
                visible: Weather.searching
                text: "searching"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.t4
            }
        }

        Timer {
            id: debounce
            interval: 350
            onTriggered: Weather.search(input.text)
        }
    }

    ListView {
        visible: root.picking
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: Weather.places
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: place
            required property var modelData
            width: ListView.view.width
            height: 48
            radius: Theme.rRow
            color: placeArea.containsMouse ? Theme.s3 : Theme.s1
            Behavior on color { ColorAnimation { duration: 160 } }

            MouseArea {
                id: placeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Weather.pick(place.modelData)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Icon { size: 18; text: "location_on"; color: Theme.t3 }
                Text {
                    text: place.modelData.name
                    font.family: Theme.ui
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.t1
                }
                Text {
                    Layout.fillWidth: true
                    text: place.modelData.detail
                    font.family: Theme.ui
                    font.pixelSize: 11
                    color: Theme.t3
                    elide: Text.ElideRight
                }
                Text {
                    text: place.modelData.lat.toFixed(2) + ", " + place.modelData.lon.toFixed(2)
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.t4
                }
            }
        }
    }

    RowLayout {
        visible: !root.picking
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            radius: Theme.rCard
            color: Theme.s1

            Column {
                anchors.centerIn: parent
                spacing: 4

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 54
                    filled: true
                    crisp: false
                    text: Weather.info.icon
                    color: Theme.accent
                }
                Temp {
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: Weather.ready ? Math.round(Weather.current.temp).toString() : "--"
                    size: 44
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.ready ? Weather.info.label : (Weather.error || "loading…")
                    font.family: Theme.ui
                    font.pixelSize: 13
                    color: Weather.error ? Theme.warning : Theme.t2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Weather.ready
                    text: Weather.ready
                        ? "feels " + Math.round(Weather.current.feels) + "° - " + Weather.current.humidity + "% - " + Math.round(Weather.current.wind) + " km/h"
                        : ""
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.t4
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: Theme.rCard
                color: Theme.s1
                clip: true

                ListView {
                    id: hours
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 12
                    anchors.bottomMargin: 14
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Weather.hourly

                    property bool wheeling: false
                    Timer {
                        id: wheelIdle
                        interval: 700
                        onTriggered: hours.wheeling = false
                    }

                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: 46
                        spacing: 5

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.index === 0 ? "now" : Weather.hourLabel(parent.modelData.time)
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.t4
                        }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 18
                            filled: true
                            crisp: false
                            text: Weather.codeInfo(parent.modelData.code, parent.modelData.isDay).icon
                            color: Theme.t2
                        }
                        Temp {
                            anchors.horizontalCenter: parent.horizontalCenter
                            value: Math.round(parent.modelData.temp).toString()
                            size: 12
                        }
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const step = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                            hours.contentX = Math.max(0, Math.min(hours.contentWidth - hours.width, hours.contentX - step));
                            hours.wheeling = true;
                            wheelIdle.restart();
                        }
                    }
                }

                Rectangle {
                    visible: hours.contentWidth > hours.width
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    x: hours.x + hours.visibleArea.xPosition * hours.width
                    width: Math.max(24, hours.visibleArea.widthRatio * hours.width)
                    height: 3
                    radius: 2
                    color: Theme.alpha(Theme.t1, 0.35)
                    opacity: hours.moving || hours.dragging || hours.wheeling ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 450 } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Repeater {
                    model: Weather.daily
                    delegate: Rectangle {
                        id: day
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.rRow
                        color: Theme.s1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            Text {
                                Layout.preferredWidth: 84
                                text: day.index === 0 ? "Today" : Weather.dayLabel(day.modelData.date)
                                font.family: Theme.ui
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.t1
                            }
                            Icon {
                                size: 17
                                filled: true
                                crisp: false
                                text: Weather.codeInfo(day.modelData.code, 1).icon
                                color: Theme.t2
                            }
                            Text {
                                Layout.fillWidth: true
                                text: Weather.codeInfo(day.modelData.code, 1).label
                                font.family: Theme.ui
                                font.pixelSize: 11
                                color: Theme.t3
                                elide: Text.ElideRight
                            }
                            Text {
                                text: Math.round(day.modelData.min) + "°"
                                font.family: Theme.mono
                                font.pixelSize: 12
                                color: Theme.t3
                            }
                            Text {
                                text: Math.round(day.modelData.max) + "°"
                                font.family: Theme.mono
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.t1
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.picking
            ? "open-meteo geocoding - pick a city to pin it"
            : (Weather.updated > 0
                ? "open-meteo - updated " + Qt.formatDateTime(new Date(Weather.updated), "HH:mm") + " - refreshes every 15 min"
                : "open-meteo - no data yet")
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.t4
    }
}
