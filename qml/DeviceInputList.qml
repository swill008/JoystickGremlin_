// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Item {
    id: _root

    property Device device

    ActionNames { id: _actionNames }

    TextInputDialog {
        id: _renameDialog

        visible: false
        width: 320

        property int rowIndex: -1

        onAccepted: (value) => {
            _actionNames.setOnModel(device, rowIndex, value)
            visible = false
        }
    }

    Connections {
        target: uiState

        function onDeviceChanged() {
            let tmp = uiState.currentInputIndex
            _inputList.currentIndex = -1
            _inputList.currentIndex = tmp
        }
    }

    Connections {
        target: signal

        function onSetInputIndex(index) {
            _inputList.currentIndex = index
        }
    }

    JGListView {
        id: _inputList

        anchors.fill: parent
        anchors.leftMargin: 10

        scrollbarAlwaysVisible: true
        spacing: 5

        model: device

        delegate: InputButton {
            width: _inputList.width - 20
            height: 50

            selected: model.index === _inputList.currentIndex
            onClicked: () => { _inputList.currentIndex = model.index }
            onRenameRequested: {
                _renameDialog.rowIndex = model.index
                _renameDialog.text = description
                _renameDialog.visible = true
            }
        }

        footer: Item {
            width: ListView.view.width
            height: 10
        }

        Component.onCompleted: () => {
            uiState.setCurrentInput(
                device.inputIdentifier(currentIndex),
                currentIndex
            )
        }

        onCurrentIndexChanged: () => {
            uiState.setCurrentInput(
                device.inputIdentifier(currentIndex),
                currentIndex
            )
        }
    }
}
