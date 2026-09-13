// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
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

    color: Style.background
    Universal.theme: Style.theme

    title: "Joystick Button Map"

    property string guid0: ""
    property string guid1: ""
    property string guid2: ""
    property int liveStamp: live0.stamp + live1.stamp + live2.stamp
        + live0.buttonStamp + live1.buttonStamp + live2.buttonStamp
        + live0.axisStamp + live1.axisStamp + live2.axisStamp
        + live0.hatStamp + live1.hatStamp + live2.hatStamp
        + buttons0.count + buttons1.count + buttons2.count
        + axes0.count + axes1.count + axes2.count
        + hats0.count + hats1.count + hats2.count

    ViewerDeviceModel { id: _devices }

    PairLiveThrottle { id: live0; guid: _buttonMap.guid0 }
    PairLiveThrottle { id: live1; guid: _buttonMap.guid1 }
    PairLiveThrottle { id: live2; guid: _buttonMap.guid2 }

    MappedButtonModel { id: buttons0; guid: _buttonMap.guid0 }
    MappedButtonModel { id: buttons1; guid: _buttonMap.guid1 }
    MappedButtonModel { id: buttons2; guid: _buttonMap.guid2 }

    MappedAxisModel { id: axes0; guid: _buttonMap.guid0 }
    MappedAxisModel { id: axes1; guid: _buttonMap.guid1 }
    MappedAxisModel { id: axes2; guid: _buttonMap.guid2 }

    MappedHatModel { id: hats0; guid: _buttonMap.guid0 }
    MappedHatModel { id: hats1; guid: _buttonMap.guid1 }
    MappedHatModel { id: hats2; guid: _buttonMap.guid2 }

    function pickDevice() {
        guid0 = ""; guid1 = ""; guid2 = ""
        if (!_devices || !_devices.listRows) {
            return
        }
        var rows = _devices.listRows() || []
        var picked = []
        var fallback = []
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            if (!row || !row.mapped) {
                continue
            }
            var name = String(row.name || "")
            if (/vkb|gladiator|evo|ste?cs|gunfighter/i.test(name)) {
                picked.push(row.guid)
            } else if (fallback.length < 3) {
                fallback.push(row.guid)
            }
        }
        var use = picked.length ? picked : fallback
        if (use.length > 0) guid0 = String(use[0] || "")
        if (use.length > 1) guid1 = String(use[1] || "")
        if (use.length > 2) guid2 = String(use[2] || "")
    }

    function _dest(model, id) {
        if (!model || !model.destLabel) {
            return ""
        }
        try {
            return String(model.destLabel(id) || "")
        } catch (e) {
            return ""
        }
    }

    function destBtn(id) {
        return _dest(buttons0, id) || _dest(buttons1, id) || _dest(buttons2, id) || "—"
    }
    function destAxis(id) {
        return _dest(axes0, id) || _dest(axes1, id) || _dest(axes2, id) || "—"
    }
    function destHat(id) {
        return _dest(hats0, id) || _dest(hats1, id) || _dest(hats2, id) || "—"
    }

    function hwButton(id) {
        liveStamp
        return Math.max(live0.buttonValue(id), live1.buttonValue(id), live2.buttonValue(id))
    }
    function hwAxis(id) {
        liveStamp
        return live0.axisValue(id) || live1.axisValue(id) || live2.axisValue(id)
    }
    function hwHat(id) {
        liveStamp
        return Math.max(live0.hatValue(id), live1.hatValue(id), live2.hatValue(id))
    }

    Connections {
        target: _devices
        function onModelReset() { _buttonMap.pickDevice() }
        function onRowsInserted() { _buttonMap.pickDevice() }
        function onRowsRemoved() { _buttonMap.pickDevice() }
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
        host: _buttonMap
        liveStamp: _buttonMap.liveStamp
    }
}
