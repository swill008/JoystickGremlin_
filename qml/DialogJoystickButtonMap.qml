// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Window {
    id: _buttonMap

    width: 980
    height: 980
    minimumWidth: 720
    minimumHeight: 720

    color: "#141414"
    Universal.theme: Style.theme

    title: "Joystick Button Map"

    property string activeGuid: ""
    property string activePair: ""

    ViewerDeviceModel { id: _devices }

    PairLiveThrottle {
        id: _live
        guid: _buttonMap.activeGuid
    }

    MappedButtonModel {
        id: _buttons
        guid: _buttonMap.activeGuid
    }

    MappedAxisModel {
        id: _axes
        guid: _buttonMap.activeGuid
    }

    function pickDevice() {
        var guid = ""
        var pair = ""
        var fallbackGuid = ""
        var fallbackPair = ""
        if (!_devices) {
            activeGuid = ""
            activePair = ""
            return
        }
        for (var i = 0; i < _devices.count; i++) {
            var row = _row(i)
            if (!row) {
                continue
            }
            if (row.mapped && !fallbackGuid) {
                fallbackGuid = row.guid
                fallbackPair = row.pairLabel
            }
            if (row.mapped && /vkb|gladiator|evo|ste?cs|gunfighter/i.test(row.name || "")) {
                guid = row.guid
                pair = row.pairLabel
                break
            }
        }
        activeGuid = guid || fallbackGuid
        activePair = pair || fallbackPair
    }

    function _row(i) {
        // ViewerDeviceModel exposes roles to Repeater; stash via _probe
        return _probe.rows[i] || null
    }

    QtObject {
        id: _probe
        property var rows: []
    }

    Repeater {
        model: _devices
        Item {
            required property string guid
            required property string name
            required property string pairLabel
            required property bool mapped
            required property int index

            Component.onCompleted: {
                _probe.rows[index] = {
                    guid: guid,
                    name: name,
                    pairLabel: pairLabel,
                    mapped: mapped
                }
                _buttonMap.pickDevice()
            }
            Component.onDestruction: {
                _probe.rows[index] = null
            }
        }
    }

    Component.onCompleted: () => {
        if (_devices) {
            _devices.reload()
        }
        pickDevice()
    }

    VkbRigFace {
        anchors.fill: parent
        anchors.margins: 8
        pairLabel: _buttonMap.activePair
        live: _live
        buttonStamp: _live && _live.buttonStamp !== undefined ? _live.buttonStamp : (_live ? _live.stamp : 0)
        axisStamp: _live && _live.axisStamp !== undefined ? _live.axisStamp : (_live ? _live.stamp : 0)
    }
}
