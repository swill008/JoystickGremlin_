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
    TextInputDialog {
        id: _renameDialog

        visible: false
        width: 320

        property int rowIndex: -1

        onAccepted: (value) => {
            _inputList.model.setActionName(rowIndex, value)
            visible = false
        }
    }

    ColumnLayout {
        id: _content

        anchors.fill: parent

        JGListView {
            id: _inputList

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.leftMargin: 10

            scrollbarAlwaysVisible: true
            spacing: 5

            model: KeyboardManagerModel {}

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

                deleteButton: IconButton {
                    text: bsi.icons.remove
                    font.pixelSize: 12
                    width: 15

                    onClicked: () => { _inputList.model.deleteInput(model.index) }
                }
            }

            footer: Item {
                width: ListView.view.width
                height: 10
            }

            onCurrentIndexChanged: () => {
                uiState.setCurrentInput(
                    model.inputIdentifier(currentIndex),
                    currentIndex
                )
            }
         }

        InputListener {
            Layout.margins: 10
            Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter

            text: "Add Key"
            callback: (inputs) => { _inputList.model.addKey(inputs) }
            multipleInputs: false
            eventTypes: ["key"]
        }
    }
}
