// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Device
import Gremlin.Style

Popup {
    id: _root

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16
    width: 420

    background: Rectangle {
        color: Style.background
        border.color: Style.accent
        border.width: 1
        radius: 4
    }

    onOpened: {
        if (_status) {
            _status.refresh()
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        width: parent ? parent.width : 420

        VJoyStatus { id: _status }

        Label {
            text: "Device tabs"
            font.bold: true
            font.pixelSize: 16
        }

        Label {
            text: "Check a device to show its tab. Mapping and New Action Sequence stay available on shown tabs."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            opacity: 0.75
            font.pixelSize: 12
        }

        Repeater {
            model: [
                {"key": "keyboard", "label": "Keyboard"},
                {"key": "logical", "label": "Logical Device"},
                {"key": "osc", "label": "OSC"}
            ]

            CheckBox {
                required property var modelData
                text: modelData.label
                checked: _status && _status.pinStamp >= 0 && _status.isExtraPinned(modelData.key)
                onToggled: {
                    if (_status) {
                        _status.setExtraPinned(modelData.key, checked)
                    }
                }
            }
        }

        Label {
            text: "vJoy  ·  " + (_status ? _status.activeCount : 0) + " of 16 installed and activated"
            font.bold: true
        }

        GridLayout {
            columns: 4
            columnSpacing: 12
            rowSpacing: 10
            Layout.fillWidth: true

            Repeater {
                model: 16

                RowLayout {
                    required property int index
                    readonly property int deviceId: index + 1
                    readonly property bool active: _status && _status.isActive(deviceId)
                    readonly property bool pinned: _status && _status.isPinned(deviceId)
                    Layout.fillWidth: true
                    spacing: 4

                    CheckBox {
                        checked: parent.pinned
                        enabled: parent.active
                        onToggled: {
                            if (_status) {
                                _status.setPinned(parent.deviceId, checked)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 4
                        color: parent.active ? Style.accent : Style.background
                        border.color: parent.active ? Style.accent : Style.lowColor
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: deviceId
                            font.bold: true
                            font.pixelSize: 14
                            color: parent.parent.active ? Style.background : Style.foreground
                            opacity: parent.parent.active ? 1.0 : 0.45
                        }
                    }
                }
            }
        }
    }
}
