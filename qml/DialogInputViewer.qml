// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Window {
    id: _inputViewer

    width: 1200
    height: 800
    minimumWidth: 800
    minimumHeight: 500

    color: Style.background
    Universal.theme: Style.theme

    title: "vJoy Pairing-Viewer"

    readonly property string oscGuid: "a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70"

    ViewerDeviceModel { id: _devices }

    function pairTitle(guid, name) {
        var key = String(guid || "").toLowerCase().replace(/[{}]/g, "")
        if (key === oscGuid) {
            return "OSC"
        }
        return name && name.length ? name : guid
    }

    Component.onCompleted: () => {
        if (_devices) {
            _devices.reload()
        }
    }

    ScrollView {
        id: _dynamicScroll
        anchors.fill: parent
        anchors.margins: 12

        Component.onCompleted: () => {
            _dynamicScroll.contentItem.boundsMovement = Flickable.StopAtBounds
            _dynamicScroll.contentItem.boundsBehavior = Flickable.StopAtBounds
        }

        ColumnLayout {
            id: _stateDisplay
            width: Math.max(_dynamicScroll.availableWidth, 760)
            spacing: 8

            Repeater {
                model: _devices
                delegate: Loader {
                    required property string guid
                    required property string name
                    required property string pairLabel
                    required property bool mapped

                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    sourceComponent: mapped ? _pairComp : _unmappedComp

                    property string _guid: guid
                    property string _name: _inputViewer.pairTitle(guid, name)
                    property string _pair: pairLabel
                }
            }
        }
    }

    Component {
        id: _pairComp
        InputViewerCard {
            deviceGuid: parent._guid
            title: parent._name
            pairLabel: parent._pair
            width: parent.width
        }
    }

    Component {
        id: _unmappedComp
        UnmappedCard {
            deviceGuid: parent._guid
            title: parent._name
            width: parent.width
        }
    }
}
