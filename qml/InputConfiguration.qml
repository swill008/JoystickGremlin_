// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Profile
import Gremlin.Style

Item {
    id: _root

    property InputItemModel inputItemModel
    property int inputIndex

    Connections {
        target: uiState

        function onInputChanged() {
            _root.inputItemModel = backend.getInputItem(
                uiState.currentInput,
                uiState.currentInputIndex
            )
        }
    }

    Connections {
        target: signal

        function onReloadCurrentInputItem() {
            _root.inputItemModel = backend.getInputItem(
                uiState.currentInput,
                uiState.currentInputIndex
            )
        }
    }

    DismissibleDialog {
        id: _selectInputDialog

        titleText: "Select an input"
        messageText: "Select an input first before adding an action sequence."
        confirmText: "OK"
    }

    ColumnLayout {
        id: _content

        anchors.fill: parent

        JGListView {
            id: _listView

            Layout.fillHeight: true
            Layout.fillWidth: true
            scrollbarAlwaysVisible: true

            model: _root.inputItemModel
            delegate: _entryDelegate
        }

        Component {
            id: _entryDelegate

            Item {
                id: _delegate

                height: _binding.height
                width: _binding.width

                required property int index
                required property var modelData
                property ListView view: ListView.view

                InputItemBinding {
                    id: _binding

                    implicitWidth: view.width

                    inputBinding: modelData
                    inputItemModel: _root.inputItemModel
                }
            }
        }

        Rectangle {
            id: _newActionButton

            Layout.fillWidth: true
            Layout.preferredHeight: 40

            color: Style.background

            Button {
                anchors.horizontalCenter: parent.horizontalCenter

                text: "New Action Sequence"

                onClicked: {
                    if (!_root.inputItemModel) {
                        _selectInputDialog.open()
                        return
                    }
                    _root.inputItemModel.newActionSequence()
                }
            }
        }
    }
}
