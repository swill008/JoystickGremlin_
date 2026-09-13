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

    color: Style.background
    Universal.theme: Style.theme

    title: "Joystick Button Map — VKBsim Gladiator EVO R"

    readonly property string targetName: "VKBsim Gladiator EVO R"
    property int _nameTick: 0

    ViewerDeviceModel { id: _devices }

    DeviceNames {
        id: _names
        onChanged: _buttonMap._nameTick++
    }

    function displayName(guid, name) {
        if (!_names) {
            return name
        }
        return _nameTick, _names.display(guid, name)
    }

    function isTarget(guid, name) {
        var raw = String(name || "")
        var shown = String(displayName(guid, raw) || "")
        if (raw === targetName || shown === targetName) {
            return true
        }
        var a = raw.toLowerCase()
        var b = shown.toLowerCase()
        if (a.indexOf("evo l") !== -1 || b.indexOf("evo l") !== -1) {
            return false
        }
        if (a.indexOf("ot l") !== -1 || b.indexOf("ot l") !== -1) {
            return false
        }
        function isRight(s) {
            return s.indexOf("gladiator") !== -1 && (s.indexOf("evo r") !== -1 || s.indexOf("ot r") !== -1)
        }
        return isRight(a) || isRight(b)
    }

    Component.onCompleted: () => {
        if (_devices) {
            _devices.reload()
        }
    }

    JGText {
        anchors.centerIn: parent
        visible: !_hasTarget.hit
        text: "Connect VKBsim Gladiator EVO R"
        opacity: 0.65
    }

    QtObject {
        id: _hasTarget
        property bool hit: false
    }

    Item {
        anchors.fill: parent
        anchors.margins: 8

        Repeater {
            model: _devices

            Item {
                required property string guid
                required property string name
                required property string pairLabel
                required property bool mapped

                anchors.fill: parent
                visible: _buttonMap.isTarget(guid, name)

                onVisibleChanged: {
                    if (visible) {
                        _hasTarget.hit = true
                    }
                }
                Component.onCompleted: {
                    if (visible) {
                        _hasTarget.hit = true
                    }
                }

                JoystickButtonMapCard {
                    anchors.fill: parent
                    deviceGuid: guid
                    title: _buttonMap.displayName(guid, name)
                    pairLabel: pairLabel
                }
            }
        }
    }
}
