// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Device
import Gremlin.Style

ColumnLayout {
    id: _root

    property string deviceGuid: ""
    property string title: ""
    property string pairLabel: ""
    property int axisStamp: _live && _live.axisStamp !== undefined ? _live.axisStamp : (_live ? _live.stamp : 0)
    property int buttonStamp: _live && _live.buttonStamp !== undefined ? _live.buttonStamp : (_live ? _live.stamp : 0)
    property bool pairActive: backend && backend.gremlinActive

    spacing: 4

    MappedAxisModel {
        id: _axes
        guid: deviceGuid
    }

    MappedButtonModel {
        id: _buttons
        guid: deviceGuid
    }

    PairLiveThrottle {
        id: _live
        guid: deviceGuid
    }

    function hwAxis(id) {
        return axisStamp >= 0 ? _live.axisValue(id) : 0
    }
    function vjAxis(g, id) {
        return axisStamp >= 0 ? _live.vjoyAxisValue(g, id) : 0
    }
    function hwButton(id) {
        return buttonStamp >= 0 ? _live.buttonValue(id) : 0
    }
    function vjButton(g, id) {
        return buttonStamp >= 0 ? _live.vjoyButtonValue(g, id) : 0
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: _inner.implicitHeight + 16
        color: pairActive ? "#052e16" : Style.background
        border.color: pairActive ? "#22C55E" : Style.accent
        border.width: pairActive ? 2 : 1
        radius: 6
        clip: true

        ColumnLayout {
            id: _inner
            width: parent.width - 16
            x: 8
            y: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                JGText {
                    text: title
                    font.pointSize: 12
                }

                Rectangle {
                    visible: pairActive
                    width: 8
                    height: 8
                    radius: 4
                    color: "#22C55E"
                }

                JGText {
                    visible: pairActive
                    text: "Active"
                    color: "#22C55E"
                    font.pointSize: 10
                }

                Item { Layout.fillWidth: true }

                JGText {
                    visible: pairLabel.length > 0
                    text: "\u2192  " + pairLabel
                    color: pairActive ? "#86EFAC" : Style.accent
                }

                Switch {
                    id: _temporal
                    text: "Axes - Temporal"
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: _temporal.checked ? 200 : 0
                visible: _temporal.checked
                clip: true

                Loader {
                    anchors.fill: parent
                    active: _temporal.checked
                    source: Qt.resolvedUrl("AxesStateSeries.qml")
                    onLoaded: {
                        if (item) {
                            item.deviceGuid = _root.deviceGuid
                            item.title = ""
                        }
                    }
                }
            }

            JGText {
                text: "Mapped axes"
                opacity: 0.7
                font.pointSize: 10
            }

            Repeater {
                model: _axes

                delegate: RowLayout {
                    required property int identifier
                    required property string label
                    required property string vjoyLabel
                    required property string vjoyGuid
                    required property int vjoyInput
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        text: label
                        color: Style.foreground
                        Layout.preferredWidth: 28
                        font.pointSize: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Style.lowColor

                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: parent.width * Math.min(1.0, Math.max(0.0, (hwAxis(identifier) + 1.0) * 0.5))
                            color: "#22C55E"
                        }
                    }

                    Label {
                        text: vjoyLabel
                        color: Style.accent
                        Layout.preferredWidth: 88
                        font.pointSize: 9
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Style.lowColor

                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: parent.width * Math.min(1.0, Math.max(0.0, (vjAxis(vjoyGuid, vjoyInput) + 1.0) * 0.5))
                            color: "#38BDF8"
                        }
                    }
                }
            }

            JGText {
                text: "Mapped buttons"
                opacity: 0.7
                font.pointSize: 10
            }

            Flow {
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: _buttons

                    delegate: Rectangle {
                        required property int identifier
                        required property string label
                        required property string vjoyLabel
                        required property string vjoyGuid
                        required property int vjoyInput

                        property bool hwOn: hwButton(identifier) > 0.5
                        property bool vjOn: vjButton(vjoyGuid, vjoyInput) > 0.5

                        width: 40
                        height: 18
                        radius: 3
                        color: Style.background
                        border.color: (hwOn || vjOn) ? "#22C55E" : Style.medColor
                        border.width: 1
                        clip: true

                        Row {
                            anchors.fill: parent

                            Rectangle {
                                width: parent.width / 2
                                height: parent.height
                                color: hwOn ? "#22C55E" : "transparent"

                                Label {
                                    anchors.centerIn: parent
                                    text: label
                                    color: hwOn ? "#052e16" : Style.foreground
                                    font.pointSize: 8
                                }
                            }

                            Rectangle {
                                width: 1
                                height: parent.height
                                color: Style.medColor
                            }

                            Rectangle {
                                width: parent.width / 2 - 1
                                height: parent.height
                                color: vjOn ? "#38BDF8" : "transparent"

                                Label {
                                    anchors.centerIn: parent
                                    text: String(vjoyInput)
                                    color: vjOn ? "#0b1220" : Style.foreground
                                    font.pointSize: 8
                                }
                            }
                        }

                        ToolTip.visible: _hover.hovered
                        ToolTip.text: label + " / " + vjoyLabel
                        HoverHandler { id: _hover }
                    }
                }
            }
        }
    }
}
