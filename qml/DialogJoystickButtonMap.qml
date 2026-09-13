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

    title: "Joystick Button Map — VKBsim Gladiator EVO R"

    readonly property string targetName: "VKBsim Gladiator EVO R"
    property string targetGuid: ""
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

    function _isTarget(name) {
        var n = String(name || "").toLowerCase()
        if (!n.length) {
            return false
        }
        if (String(name) === targetName) {
            return true
        }
        // Right stick only. Do not take EVO L / OT L.
        if (n.indexOf("evo l") !== -1 || n.indexOf("ot l") !== -1) {
            return false
        }
        return n.indexOf("gladiator") !== -1 && (n.indexOf("evo r") !== -1 || n.indexOf("ot r") !== -1)
    }

    function pickDevice() {
        guid0 = ""
        guid1 = ""
        guid2 = ""
        targetGuid = ""
        if (!_devices || !_devices.guidForDeviceName) {
            return
        }
        var guid = String(_devices.guidForDeviceName(targetName) || "")
        if (!guid.length) {
            return
        }
        targetGuid = guid
        guid0 = guid
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
