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
    property var _axisWidget: null
    property var _buttonWidget: null

    spacing: 8

    InputPairing { id: _pairing }

    function _validGuid() {
        return String(deviceGuid).replace(/[{}]/g, "").length >= 32
    }

    function _rebuild() {
        if (_axisWidget) {
            _axisWidget.destroy()
            _axisWidget = null
        }
        if (_buttonWidget) {
            _buttonWidget.destroy()
            _buttonWidget = null
        }
        if (!_validGuid()) {
            return
        }
        let axisComp = Qt.createComponent(Qt.resolvedUrl("AxesStateCurrent.qml"))
        if (axisComp.status === Component.Ready) {
            _axisWidget = axisComp.createObject(_inner, {
                deviceGuid: deviceGuid,
                title: title,
                "Layout.fillWidth": true,
                "Layout.preferredHeight": 170
            })
        }
        let btnComp = Qt.createComponent(Qt.resolvedUrl("ButtonState.qml"))
        if (btnComp.status === Component.Ready) {
            _buttonWidget = btnComp.createObject(_inner, {
                deviceGuid: deviceGuid,
                title: title,
                "Layout.fillWidth": true,
                "Layout.preferredHeight": 240
            })
        }
    }

    Component.onCompleted: _rebuild()
    onDeviceGuidChanged: _rebuild()

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
        }
    }
}
