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

    readonly property bool editorLocked: backend && backend.gremlinActive
    enabled: !editorLocked
    opacity: editorLocked ? 0.55 : 1.0

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
            if (editorLocked) {
                return
            }
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
                enabled: !editorLocked

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
                    _textInput.text = description
                    _textInput.callback = (value) => {
                        _actionNames.setOnModel(_inputList.model, index, value)
                    }
                    _textInput.visible = true
                }

                editButton: IconButton {
                    text: bsi.icons.edit
                    font.pixelSize: 12
                    width: 15
                    enabled: !editorLocked

                    onClicked: () => {
                        if (editorLocked) {
                            return
                        }
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
                    enabled: !editorLocked

                    onClicked: () => {
                        if (!editorLocked) {
                            _inputList.model.deleteInput(label)
                        }
                    }
                }
            }

            footer: Item {
                width: ListView.view.width
                height: 10
            }

            onCurrentIndexChanged: () => {
                if (editorLocked) {
                    return
                }
                inputIndex = currentIndex
                inputIdentifier = model.inputIdentifier(currentIndex)
            }
        }

        RowLayout {
            Layout.minimumWidth: 100
            Layout.preferredHeight: 50
            enabled: !editorLocked

            ComboBox {
                id: _input_type

                Layout.fillWidth: true
                Layout.leftMargin: 5

                model: ["Axis", "Button", "Hat"]
            }

            Button {
                Layout.preferredHeight: _input_type.height
                Layout.rightMargin: 5
                enabled: !editorLocked

                text: bsi.icons.add
                font.family: "bootstrap-icons"

                onClicked: () => {
                    if (!editorLocked) {
                        _inputList.model.createInput(_input_type.currentValue)
                    }
                }
            }
        }
    }
}
