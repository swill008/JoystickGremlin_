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
    padding: 14
    width: 360

    VJoyStatus { id: _status }

    background: Rectangle {
        color: Style.background
        border.color: Style.accent
        border.width: 1
        radius: 4
    }

    onOpened: _status.refresh()

    contentItem: ColumnLayout {
        spacing: 10

        Label {
            text: "vJoy devices"
            font.bold: true
            font.pixelSize: 16
        }

        Label {
            text: _status.activeCount + " of 16 installed and activated"
            opacity: 0.8
        }

        Label {
            text: "Check a device to show its tab. Mapping and New Action Sequence stay available on shown tabs."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            opacity: 0.75
            font.pixelSize: 12
        }

        GridLayout {
            columns: 4
            columnSpacing: 10
            rowSpacing: 8
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: 16

                RowLayout {
                    required property int index
                    readonly property int deviceId: index + 1
                    readonly property bool active: _status.activeCount >= 0 && _status.isActive(deviceId)
                    readonly property bool pinned: _status.pinStamp >= 0 && _status.isPinned(deviceId)
                    spacing: 4

                    CheckBox {
                        checked: parent.pinned
                        enabled: parent.active
                        onToggled: _status.setPinned(parent.deviceId, checked)
                    }

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 32
                        radius: 4
                        color: parent.active ? Style.accent : Style.background
                        border.color: parent.active ? Style.accent : Style.lowColor
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: parent.parent.deviceId
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
