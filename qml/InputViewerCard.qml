// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Device
import Gremlin.Style

Item {
    id: _root

    property string deviceGuid: ""
    property string title: ""
    property string pairLabel: _pairing.pairedDeviceLabel(deviceGuid)

    implicitHeight: _content.implicitHeight + 16

    InputPairing { id: _pairing }

    DeviceAxisState {
        id: _axes
        guid: deviceGuid
    }

    DeviceButtonState {
        id: _buttons
        guid: deviceGuid
    }

    Rectangle {
        anchors.fill: parent
        color: Style.background
        border.color: Style.backgroundShade
        border.width: 1
        radius: 6
    }

    ColumnLayout {
        id: _content
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
                font.weight: 600
            }

            Item { Layout.fillWidth: true }

            JGText {
                visible: pairLabel.length > 0
                text: "→  " + pairLabel
                color: Style.accent
            }
        }

        JGText {
            visible: _axes.rowCount() > 0
            text: "Axes"
            color: Style.foreground
            opacity: 0.7
        }

        Row {
            id: _axisRow
            Layout.fillWidth: true
            spacing: 12
            visible: _axes.rowCount() > 0

            Repeater {
                model: _axes

                delegate: Column {
                    required property int identifier
                    required property double value
                    width: 56
                    spacing: 4

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: _pairing.axisLabel(identifier)
                        color: Style.foreground
                        font.pointSize: 10
                    }

                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Style.lowColor

                        Rectangle {
                            width: Math.max(4, parent.width * ((value + 1.0) * 0.5))
                            height: parent.height
                            radius: 4
                            color: "#22C55E"
                        }
                    }
                }
            }
        }

        JGText {
            visible: _buttons.rowCount() > 0
            text: "Buttons"
            color: Style.foreground
            opacity: 0.7
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: _buttons.rowCount() > 0

            Repeater {
                model: _buttons

                delegate: Rectangle {
                    required property int identifier
                    required property var value

                    width: 36
                    height: 36
                    radius: 18
                    color: value ? "#22C55E" : Style.background
                    border.color: value ? "#16A34A" : Style.medColor
                    border.width: 1

                    Label {
                        anchors.centerIn: parent
                        text: identifier
                        color: value ? "#052e16" : Style.foreground
                        font.pointSize: 10
                        font.weight: 600
                    }
                }
            }
        }
    }
}
