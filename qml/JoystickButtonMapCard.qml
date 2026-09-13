// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Layouts

import Gremlin.Device
import Gremlin.Style

Item {
    id: _root

    property string deviceGuid: ""
    property string title: ""
    property string pairLabel: ""

    property int liveStamp: (_live ? _live.stamp : 0)
        + (_live && _live.buttonStamp !== undefined ? _live.buttonStamp : 0)
        + (_live && _live.axisStamp !== undefined ? _live.axisStamp : 0)
        + (_live && _live.hatStamp !== undefined ? _live.hatStamp : 0)
        + _buttons.count + _axes.count + _hats.count

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

    function hwButton(id) {
        liveStamp
        return _live ? _live.buttonValue(id) : 0
    }
    function hwAxis(id) {
        liveStamp
        return _live ? _live.axisValue(id) : 0
    }
    function hwHat(id) {
        liveStamp
        return _live ? _live.hatValue(id) : 0
    }
    function destBtn(id) {
        liveStamp
        var label = _buttons && _buttons.destLabel ? String(_buttons.destLabel(id) || "") : ""
        return label.length ? label : "—"
    }
    function destAxis(id) {
        liveStamp
        var label = _axes && _axes.destLabel ? String(_axes.destLabel(id) || "") : ""
        return label.length ? label : "—"
    }
    function destHat(id) {
        liveStamp
        var label = _hats && _hats.destLabel ? String(_hats.destLabel(id) || "") : ""
        return label.length ? label : "—"
    }

    VkbRigFace {
        anchors.fill: parent
        host: _root
        liveStamp: _root.liveStamp
    }
}
