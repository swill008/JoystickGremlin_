// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick

import Gremlin.Device
import Gremlin.Style

// Same live stack as qml/InputViewerCard.qml (vJoy Pairing).
Item {
    id: _root

    property string deviceGuid: ""
    property string title: ""
    property string pairLabel: ""

    property int axisStamp: _live && _live.axisStamp !== undefined ? _live.axisStamp : (_live ? _live.stamp : 0)
    property int buttonStamp: _live && _live.buttonStamp !== undefined ? _live.buttonStamp : (_live ? _live.stamp : 0)
    property int hatStamp: _live && _live.hatStamp !== undefined ? _live.hatStamp : (_live ? _live.stamp : 0)
    property int liveStamp: buttonStamp + axisStamp + hatStamp + _buttons.count + _axes.count + _hats.count

    property var btnDest: ({})
    property var axisDest: ({})
    property var hatDest: ({})

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

    Repeater {
        model: _buttons
        Item {
            required property int identifier
            required property string vjoyLabel
            Component.onCompleted: {
                var m = _root.btnDest
                m[identifier] = vjoyLabel
                _root.btnDest = m
            }
        }
    }

    Repeater {
        model: _axes
        Item {
            required property int identifier
            required property string vjoyLabel
            Component.onCompleted: {
                var m = _root.axisDest
                m[identifier] = vjoyLabel
                _root.axisDest = m
            }
        }
    }

    Repeater {
        model: _hats
        Item {
            required property int identifier
            required property string vjoyLabel
            Component.onCompleted: {
                var m = _root.hatDest
                m[identifier] = vjoyLabel
                _root.hatDest = m
            }
        }
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
    function destBtn(id) {
        liveStamp
        var label = String(_root.btnDest[id] || "")
        return label.length ? label : "—"
    }
    function destAxis(id) {
        liveStamp
        var label = String(_root.axisDest[id] || "")
        return label.length ? label : "—"
    }
    function destHat(id) {
        liveStamp
        var label = String(_root.hatDest[id] || "")
        return label.length ? label : "—"
    }

    VkbRigFace {
        anchors.fill: parent
        host: _root
        liveStamp: _root.liveStamp
    }
}
