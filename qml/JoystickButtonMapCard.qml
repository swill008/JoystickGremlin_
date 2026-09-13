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

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        VkbRigFace {
            Layout.fillWidth: true
            Layout.fillHeight: true
            host: _root
            liveStamp: _root.liveStamp
            buttons: _buttons
            axes: _axes
            hats: _hats
        }

        // Exact pairing dest: Repeater owns vjoyLabel.
        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: 6

            Repeater {
                model: _buttons
                Rectangle {
                    required property int identifier
                    required property string vjoyLabel
                    property bool hwOn: _root.buttonStamp >= 0 && _root.hwButton(identifier) > 0.5
                    implicitWidth: _chip.implicitWidth + 14
                    implicitHeight: 24
                    radius: 4
                    color: hwOn ? "#14532D" : "#18181B"
                    border.color: hwOn ? "#22C55E" : "#3F3F46"
                    Text {
                        id: _chip
                        anchors.centerIn: parent
                        color: hwOn ? "#BBF7D0" : "#E4E4E7"
                        font.pixelSize: 11
                        text: "HW " + identifier + "  →  " + vjoyLabel
                    }
                }
            }
        }
    }
}
