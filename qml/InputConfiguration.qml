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
    property bool isOutput: false
    property bool inlineMode: false
    readonly property bool editorLocked: backend && backend.gremlinActive && !isOutput
    enabled: true
    opacity: editorLocked ? 0.55 : 1.0
    implicitHeight: inlineMode ? Math.max(80, _content.implicitHeight) : 200

    Component.onCompleted: {
        if (!backend || !uiState)
            return
        _root.inputItemModel = backend.getInputItem(
            uiState.currentInput,
            uiState.currentInputIndex
        )
    }

    Connections {
        target: uiState

        function onInputChanged() {
            if (!backend || !uiState) {
                return
            }
            _root.inputItemModel = backend.getInputItem(
                uiState.currentInput,
                uiState.currentInputIndex
            )
        }
    }

    Connections {
        target: signal

        function onReloadCurrentInputItem() {
            if (!backend || !uiState) {
                return
            }
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

        anchors.fill: inlineMode ? undefined : parent
        width: parent.width
        spacing: 8

        Repeater {
            id: _inlineRepeater
            model: _root.inlineMode ? _root.inputItemModel : null

            delegate: InputItemBinding {
                Layout.fillWidth: true
                enabled: !editorLocked
                inputBinding: modelData
                inputItemModel: _root.inputItemModel
            }
        }

        JGListView {
            id: _listView
            visible: !_root.inlineMode
            Layout.fillHeight: true
            Layout.fillWidth: true
            scrollbarAlwaysVisible: true
            enabled: !editorLocked
            model: _root.inlineMode ? null : _root.inputItemModel
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
                    enabled: !editorLocked

                    inputBinding: modelData
                    inputItemModel: _root.inputItemModel
                }
            }
        }
    }
}
