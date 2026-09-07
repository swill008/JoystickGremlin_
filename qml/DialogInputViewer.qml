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

    title: "Input Viewer"

    readonly property string oscGuid: "a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70"

    PairDeviceModel { id: _pairs }

    function pairTitle(guid, name) {
        var key = String(guid || "").toLowerCase().replace(/[{}]/g, "")
        if (key === oscGuid) {
            return "OSC"
        }
        return name && name.length ? name : guid
    }

    Connections {
        target: _inputViewer

        function onClosing() {
            backend.resumeInputHighlighting()
        }
    }

    Component.onCompleted: () => {
        backend.pauseInputHighlighting()
        if (_pairs) {
            _pairs.reload()
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
            spacing: 12

            Repeater {
                model: _pairs
                delegate: InputViewerCard {
                    required property string guid
                    required property string name
                    required property string pairLabel

                    Layout.fillWidth: true
                    deviceGuid: guid
                    title: _inputViewer.pairTitle(guid, name)
                    pairLabel: pairLabel
                }
            }
        }
    }
}
