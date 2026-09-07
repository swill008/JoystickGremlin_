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
    width: 280

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

        GridLayout {
            columns: 4
            columnSpacing: 8
            rowSpacing: 8
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: 16

                Rectangle {
                    required property int index
                    readonly property int deviceId: index + 1
                    readonly property bool active: _status.isActive(deviceId)

                    implicitWidth: 52
                    implicitHeight: 36
                    radius: 4
                    color: active ? Style.accent : Style.background
                    border.color: active ? Style.accent : Style.lowColor
                    border.width: 1

                    Label {
                        anchors.centerIn: parent
                        text: parent.deviceId
                        font.bold: true
                        font.pixelSize: 14
                        color: parent.active ? Style.background : Style.foreground
                        opacity: parent.active ? 1.0 : 0.45
                    }
                }
            }
        }
    }
}
