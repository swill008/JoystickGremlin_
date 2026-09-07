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

    spacing: 6

    MappedAxisModel {
        id: _axes
        guid: deviceGuid
    }

    MappedButtonModel {
        id: _buttons
        guid: deviceGuid
    }

    PairLiveState {
        id: _live
        guid: deviceGuid
    }

    property int liveStamp: _live ? _live.stamp : 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: _inner.implicitHeight + 20
        color: Style.background
        border.color: Style.accent
        border.width: 1
        radius: 6

        ColumnLayout {
            id: _inner
            width: parent.width - 20
            x: 10
            y: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                JGText {
                    text: title
                    font.pointSize: 13
                }

                Item { Layout.fillWidth: true }

                JGText {
                    visible: pairLabel.length > 0
                    text: "\u2192  " + pairLabel
                    color: Style.accent
                }
            }

            JGText {
                visible: _axes.count > 0 || _axes.rowCount() > 0
                text: "Mapped axes"
                opacity: 0.7
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
                    spacing: 10

                    Label {
                        text: label
                        color: Style.foreground
                        Layout.preferredWidth: 36
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        radius: 5
                        color: Style.lowColor

                        Rectangle {
                            height: parent.height
                            radius: 5
                            width: parent.width * Math.min(1.0, Math.max(0.0, ((_live.axisValue(identifier) + 1.0) * 0.5)))
                            color: "#22C55E"
                        }
                    }

                    Label {
                        text: vjoyLabel
                        color: Style.accent
                        Layout.preferredWidth: 110
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        radius: 5
                        color: Style.lowColor

                        Rectangle {
                            height: parent.height
                            radius: 5
                            width: parent.width * Math.min(1.0, Math.max(0.0, ((_live.vjoyAxisValue(vjoyGuid, vjoyInput) + 1.0) * 0.5)))
                            color: "#38BDF8"
                        }
                    }

                    property int _tick: _root.liveStamp
                }
            }

            JGText {
                text: "Mapped buttons"
                opacity: 0.7
                visible: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: _buttons

                    delegate: Rectangle {
                        required property int identifier
                        required property string label
                        required property string vjoyLabel
                        required property string vjoyGuid
                        required property int vjoyInput

                        property bool hwOn: _live.buttonValue(identifier) > 0.5
                        property bool vjOn: _live.vjoyButtonValue(vjoyGuid, vjoyInput) > 0.5
                        property int _tick: _root.liveStamp

                        width: 72
                        height: 36
                        radius: 6
                        color: (hwOn || vjOn) ? "#166534" : Style.background
                        border.color: (hwOn || vjOn) ? "#22C55E" : Style.medColor
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: label
                                color: Style.foreground
                                font.pointSize: 10
                                font.weight: 600
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: vjoyLabel
                                color: Style.accent
                                font.pointSize: 8
                            }
                        }
                    }
                }
            }
        }
    }
}
