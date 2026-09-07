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
    property string pairLabel: _pairing ? _pairing.pairedDeviceLabel(deviceGuid) : ""

    spacing: 8

    InputPairing { id: _pairing }

    DeviceAxisState {
        id: _axes
        guid: deviceGuid
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: _inner.implicitHeight + 24
        color: Style.background
        border.color: Style.accent
        border.width: 1
        radius: 6

        ColumnLayout {
            id: _inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

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
                text: "Axes"
                opacity: 0.7
            }

            Row {
                Layout.fillWidth: true
                spacing: 14

                Repeater {
                    model: _axes

                    delegate: Column {
                        required property int identifier
                        required property double value
                        width: 64
                        spacing: 4

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: _pairing ? _pairing.axisLabel(identifier) : ("A" + identifier)
                            color: Style.foreground
                            font.pointSize: 10
                        }

                        Rectangle {
                            width: parent.width
                            height: 10
                            radius: 5
                            color: Style.lowColor

                            Rectangle {
                                height: parent.height
                                radius: 5
                                width: Math.max(4, parent.width * Math.min(1.0, Math.max(0.0, (value + 1.0) * 0.5)))
                                color: "#22C55E"
                            }
                        }
                    }
                }
            }

            AxesStateCurrent {
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                deviceGuid: _root.deviceGuid
                title: ""
            }

            ButtonState {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                deviceGuid: _root.deviceGuid
                title: ""
            }
        }
    }
}
