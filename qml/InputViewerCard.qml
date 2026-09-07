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

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: _inner.implicitHeight + 24
        color: Style.background
        border.color: Style.accent
        border.width: 1
        radius: 6

        ColumnLayout {
            id: _inner
            width: parent.width - 24
            x: 12
            y: 12
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

            Loader {
                id: _axisLoader
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                source: Qt.resolvedUrl("AxesStateCurrent.qml")
                onLoaded: {
                    if (item) {
                        item.deviceGuid = _root.deviceGuid
                        item.title = _root.title
                    }
                }
            }

            Loader {
                id: _buttonLoader
                Layout.fillWidth: true
                Layout.preferredHeight: 240
                source: Qt.resolvedUrl("ButtonState.qml")
                onLoaded: {
                    if (item) {
                        item.deviceGuid = _root.deviceGuid
                        item.title = _root.title
                    }
                }
            }
        }
    }

    onDeviceGuidChanged: {
        if (_axisLoader.item) {
            _axisLoader.item.deviceGuid = deviceGuid
        }
        if (_buttonLoader.item) {
            _buttonLoader.item.deviceGuid = deviceGuid
        }
    }
}
