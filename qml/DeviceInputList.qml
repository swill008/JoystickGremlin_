// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Config
import Gremlin.Device
import Gremlin.Style

Item {
    id: _root

    property Device device
    readonly property bool editorLocked: backend && backend.gremlinActive
    enabled: !editorLocked
    opacity: editorLocked ? 0.55 : 1.0

    DeviceLiveState {
        id: _liveState
        guid: device ? device.guid : ""
        locked: editorLocked
    }

    HighlightSpeedModel {
        id: _highlightSpeed
    }

    ActionNames { id: _actionNames }

    TextInputDialog {
        id: _renameDialog

        visible: false
        width: 320

        property int rowIndex: -1

        onAccepted: (value) => {
            if (editorLocked) {
                return
            }
            _actionNames.setOnModel(device, rowIndex, value)
            visible = false
        }
    }

    Connections {
        target: uiState

        function onDeviceChanged() {
            if (!uiState || editorLocked) {
                return
            }
            let tmp = uiState.currentInputIndex
            if (tmp < 0) {
                return
            }
            if (_inputList.currentIndex !== tmp) {
                _inputList.currentIndex = tmp
            }
        }
    }

    Connections {
        target: signal

        function onSetInputIndex(index) {
            if (editorLocked || index < 0) {
                return
            }
            _inputList.currentIndex = index
        }
    }

    JGListView {
        id: _inputList

        anchors.fill: parent
        anchors.leftMargin: 10

        scrollbarAlwaysVisible: true
        spacing: 5
        highlightFollowsCurrentItem: true
        highlightMoveVelocity: -1
        highlightMoveDuration: {
            if (!_highlightSpeed) {
                return 150
            }
            if (_highlightSpeed.speed === "Fast") {
                return 0
            }
            if (_highlightSpeed.speed === "Medium") {
                return 70
            }
            return 150
        }
        highlightResizeDuration: highlightMoveDuration

        model: device

        delegate: InputButton {
            width: _inputList.width - 20
            height: 50
            enabled: !editorLocked

            liveState: editorLocked ? null : _liveState
            selected: model.index === _inputList.currentIndex
            onClicked: () => {
                if (!editorLocked) {
                    _inputList.currentIndex = model.index
                }
            }
            onRenameRequested: {
                if (editorLocked) {
                    return
                }
                _renameDialog.rowIndex = model.index
                let current = _actionNames.getOnModel(device, model.index)
                _renameDialog.text = current.length ? current : ""
                _renameDialog.visible = true
            }
        }

        footer: Item {
            width: ListView.view.width
            height: 10
        }

        function syncSelection() {
            if (!uiState || !device || currentIndex < 0 || editorLocked) {
                return
            }
            var ident = device.inputIdentifier(currentIndex)
            if (!ident) {
                return
            }
            uiState.setCurrentInput(ident, currentIndex)
        }

        Component.onCompleted: syncSelection()
        onCurrentIndexChanged: syncSelection()
    }
}
