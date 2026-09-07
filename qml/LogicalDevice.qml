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

    DeviceNames { id: _names }

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

            model: LogicalDeviceManagementModel {}

            delegate: InputButton {
                width: _inputList.width - 20
                height: 50

                selected: model.index === _inputList.currentIndex
                nameKey: "logical:" + label
                onClicked: () => { _inputList.currentIndex = model.index }
                onRenameRequested: {
                    _textInput.text = _names.display(nameKey, name)
                    _textInput.callback = (value) => { _names.setAlias(nameKey, value) }
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

        RowLayout {
            Layout.minimumWidth: 100
            Layout.preferredHeight: 50

            ComboBox {
                id: _input_type

                Layout.fillWidth: true
                Layout.leftMargin: 5

                model: ["Axis", "Button", "Hat"]
            }

            Button {
                Layout.preferredHeight: _input_type.height
                Layout.rightMargin: 5

                text: bsi.icons.add
                font.family: "bootstrap-icons"

                onClicked: () => {
                    _inputList.model.createInput(_input_type.currentValue)
                }
            }
        }
    }
}
