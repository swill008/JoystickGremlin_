// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import QtQuick.Controls.Universal

import Gremlin.Device
import Gremlin.Profile

Item {
    id: _root

    property DeviceListModel deviceListModel
    property int _nameTick: 0
    property int _vjoyTick: 0

    DeviceNames {
        id: _names

        onChanged: _root._nameTick++
    }

    VJoyStatus {
        id: _vjoy

        onChanged: _root._vjoyTick++
    }

    TextInputDialog {
        id: _renameDialog

        visible: false
        width: 320

        property string nameKey: ""
        property string fallback: ""

        onAccepted: (value) => {
            _names.setAlias(nameKey, value)
            visible = false
        }
    }

    function rename(key, fallback) {
        _renameDialog.nameKey = key
        _renameDialog.fallback = fallback
        _renameDialog.text = _names.display(key, fallback)
        _renameDialog.visible = true
    }

    function nextTab() {
        _deviceList.itemAt(_deviceList.currentIndex + 1)?.clicked()
    }

    function previousTab() {
        _deviceList.itemAt(_deviceList.currentIndex - 1)?.clicked()
    }

    function isVjoyTab(deviceName, vjoyId) {
        var label = String(deviceName || "").toLowerCase()
        return label.indexOf("vjoy") === 0 || Number(vjoyId) > 0
    }

    function showDeviceTab(deviceName, vjoyId) {
        if (!_root.isVjoyTab(deviceName, vjoyId)) {
            return true
        }
        return _root._vjoyTick >= 0 && _vjoy.isPinned(Number(vjoyId))
    }

    Component.onCompleted: {
        if (deviceListModel) {
            deviceListModel.deviceType = "all"
        }
        _vjoy.refresh()
    }

    DeviceTabBar {
        id: _deviceList

        anchors.fill: parent

        Repeater {
            id: _physicalInputs
            model: deviceListModel

            JGTabButton {
                id: _button

                visible: _root.showDeviceTab(name, vjoy_id)
                text: _root._nameTick, _names.display(model.guid, name)
                width: visible ? _metric.width + 50 : 0
                checked: uiState && uiState.currentTab === "physical" &&
                    uiState.currentDevice === model.guid

                ToolTip.visible: hovered && visible
                ToolTip.delay: 400
                ToolTip.text: name

                onClicked: () => {
                    if (!uiState) {
                        return
                    }
                    uiState.setCurrentTab("physical")
                    uiState.setCurrentDevice(model.guid)
                }

                TapHandler {
                    onDoubleTapped: {
                        if (visible) {
                            _root.rename(model.guid, name)
                        }
                    }
                }

                TextMetrics {
                    id: _metric

                    font: _button.font
                    text: _button.text
                }
            }
        }

        JGTabButton {
            id: _keyboardButton

            text: _root._nameTick, _names.display("keyboard", "Keyboard")
            width: _metricKeyboard.width + 50
            checked: uiState && uiState.currentTab === "keyboard"

            ToolTip.visible: hovered
            ToolTip.delay: 400
            ToolTip.text: "Keyboard"

            onClicked: () => {
                if (!uiState) {
                    return
                }
                uiState.setCurrentTab("keyboard")
                uiState.setCurrentDevice("6f1d2b61-d5a0-11cf-bfc7-444553540000")
            }

            TapHandler {
                onDoubleTapped: _root.rename("keyboard", "Keyboard")
            }

            TextMetrics {
                id: _metricKeyboard

                font: _keyboardButton.font
                text: _keyboardButton.text
            }
        }

        JGTabButton {
            id: _logicalButton

            text: _root._nameTick, _names.display("logical", "Logical Device")
            width: _metricIO.width + 50
            checked: uiState && uiState.currentTab === "logical"

            ToolTip.visible: hovered
            ToolTip.delay: 400
            ToolTip.text: "Logical Device"

            onClicked: () => {
                if (!uiState) {
                    return
                }
                uiState.setCurrentTab("logical")
                uiState.setCurrentDevice("f0af472f-8e17-493b-a1eb-7333ee8543f2")
            }

            TapHandler {
                onDoubleTapped: _root.rename("logical", "Logical Device")
            }

            TextMetrics {
                id: _metricIO

                font: _logicalButton.font
                text: _logicalButton.text
            }
        }

        JGTabButton {
            id: _oscButton

            text: _root._nameTick, _names.display("osc", "OSC")
            width: _metricOsc.width + 50
            checked: uiState && uiState.currentTab === "osc"

            ToolTip.visible: hovered
            ToolTip.delay: 400
            ToolTip.text: "OSC"

            onClicked: () => {
                if (!uiState) {
                    return
                }
                uiState.setCurrentTab("osc")
                uiState.setCurrentDevice("a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70")
            }

            TapHandler {
                onDoubleTapped: _root.rename("osc", "OSC")
            }

            TextMetrics {
                id: _metricOsc

                font: _oscButton.font
                text: _oscButton.text
            }
        }
    }
}
