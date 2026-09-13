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

    ViewerDeviceModel { id: _devices }

    function isTarget(name) {
        var text = String(name || "")
        var n = text.toLowerCase()
        if (text === targetName) {
            return true
        }
        if (n.indexOf("evo l") !== -1 || n.indexOf("ot l") !== -1) {
            return false
        }
        return n.indexOf("gladiator") !== -1 && (n.indexOf("evo r") !== -1 || n.indexOf("ot r") !== -1)
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
                visible: _buttonMap.isTarget(name)

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
                    title: name
                    pairLabel: pairLabel
                }
            }
        }
    }
}
