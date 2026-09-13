// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick

import Gremlin.Device
import Gremlin.Style

Item {
    id: _root

    property string deviceGuid: ""
    property string title: ""
    property string pairLabel: ""

    property int axisStamp: _live && _live.axisStamp !== undefined ? _live.axisStamp : (_live ? _live.stamp : 0)
    property int buttonStamp: _live && _live.buttonStamp !== undefined ? _live.buttonStamp : (_live ? _live.stamp : 0)
    property int hatStamp: _live && _live.hatStamp !== undefined ? _live.hatStamp : (_live ? _live.stamp : 0)
    property int liveStamp: buttonStamp + axisStamp + hatStamp + _buttons.count + _axes.count + _hats.count

    PairLiveThrottle {
        id: _live
        guid: _root.deviceGuid
    }

    MappedButtonModel {
        id: _buttons
        guid: _root.deviceGuid
    }

    MappedAxisModel {
        id: _axes
        guid: _root.deviceGuid
    }

    MappedHatModel {
        id: _hats
        guid: _root.deviceGuid
    }

    function hwAxis(id) {
        if (!_live) {
            return 0
        }
        return axisStamp >= 0 ? _live.axisValue(id) : 0
    }
    function hwButton(id) {
        if (!_live) {
            return 0
        }
        return buttonStamp >= 0 ? _live.buttonValue(id) : 0
    }
    function hwHat(id) {
        if (!_live) {
            return 0
        }
        return hatStamp >= 0 ? _live.hatValue(id) : 0
    }

    function _roleDest(model, id) {
        if (!model) {
            return ""
        }
        if (model.destLabel) {
            try {
                var slot = String(model.destLabel(id) || "")
                if (slot.length) {
                    return slot
                }
            } catch (e) {
            }
        }
        var identRole = 0x0100 + 1
        var labelRole = 0x0100 + 5
        for (var i = 0; i < model.count; i++) {
            var idx = model.index(i, 0)
            if (Number(model.data(idx, identRole)) === Number(id)) {
                return String(model.data(idx, labelRole) || "")
            }
        }
        return ""
    }

    function destBtn(id) {
        liveStamp
        var label = _roleDest(_buttons, id)
        if (label.length) {
            return label
        }
        if (pairLabel && pairLabel.length) {
            return pairLabel + " Btn " + id
        }
        return "—"
    }
    function destAxis(id) {
        liveStamp
        var label = _roleDest(_axes, id)
        if (label.length) {
            return label
        }
        if (pairLabel && pairLabel.length) {
            return pairLabel + " Axis " + id
        }
        return "—"
    }
    function destHat(id) {
        liveStamp
        var label = _roleDest(_hats, id)
        if (label.length) {
            return label
        }
        if (pairLabel && pairLabel.length) {
            return pairLabel + " Hat " + id
        }
        return "—"
    }

    VkbRigFace {
        anchors.fill: parent
        host: _root
        liveStamp: _root.liveStamp
    }
}
