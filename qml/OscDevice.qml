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

    property int inputIndex
    property InputIdentifier inputIdentifier
    property alias device: _inputList.model

    ActionNames { id: _actionNames }

    TextInputDialog {
        id: _textInput

        visible: false
        width: 300

        property var callback: null

        onAccepted: (value) => {
            callback(value)
            visible = false
        }
    }

    DismissibleDialog {
        id: _clearDialog

        titleText: "Clear OSC inputs"
        messageText: "This will remove every OSC input in the current profile."
        confirmText: "Clear"
        cancelText: "Cancel"
        destructive: true

        onConfirmed: _inputList.model.clearAllInputs()
    }

    OscImportDialog {
        id: _importDialog

        onAccepted: (text) => {
            _inputList.model.importInputs(text)
        }
    }

    OscAddDialog {
        id: _addDialog

        deviceModel: _inputList.model

        onAccepted: (cmd, mode) => {
            _inputList.model.createMappedInput(mode, cmd)
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

            model: OscDeviceManagementModel {}

            delegate: InputButton {
                width: _inputList.width - 20
                height: 50

                selected: model.index === _inputList.currentIndex
                onClicked: () => { _inputList.currentIndex = model.index }
                onRenameRequested: {
                    let current = _actionNames.getOnModel(_inputList.model, index)
                    _textInput.text = current.length ? current : ""
                    _textInput.callback = (value) => {
                        _actionNames.setOnModel(_inputList.model, index, value)
                    }
                    _textInput.visible = true
                }

                editButton: IconButton {
                    text: bsi.icons.edit
                    font.pixelSize: 12
                    width: 15

                    onClicked: () => {
                        _textInput.text = label
                        _textInput.callback = (value) => {
                            _inputList.model.changeName(label, value)
                        }
                        _textInput.visible = true
                    }
                }

                deleteButton: IconButton {
                    text: bsi.icons.remove
                    font.pixelSize: 12
                    width: 15

                    onClicked: () => { _inputList.model.deleteInput(label) }
                }
            }

            footer: Item {
                width: ListView.view.width
                height: 10
            }

            onCurrentIndexChanged: () => {
                inputIndex = currentIndex
                inputIdentifier = model.inputIdentifier(currentIndex)
            }
        }

        Connections {
            target: _inputList.model

            function onListenBound(index) {
                _inputList.currentIndex = index
                inputIndex = index
                inputIdentifier = _inputList.model.inputIdentifier(index)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.leftMargin: 10
            Layout.rightMargin: 10

            Button {
                text: "Clear"
                onClicked: _clearDialog.open()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Sort"
                onClicked: _inputList.model.sortInputs()
            }
            Button {
                text: "Add"
                onClicked: {
                    _addDialog.resetFields()
                    _addDialog.open()
                }
            }
            Button {
                text: "Import"
                onClicked: {
                    _importDialog.resetFields()
                    _importDialog.open()
                }
            }
        }
    }
}
