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
    property bool compactMode: false
    property int sequenceIndex: -1
    property color editorFill: "#0F2744"
    property color editorEdge: "#3B82F6"
    property color editorAccent: "#3B82F6"
    property int editorRadius: 3
    property int editorBorderW: 1
    property int editorAccentW: 3
    property bool showAccent: true
    property int editorPad: 10
    readonly property bool editorLocked: backend && backend.gremlinActive && !isOutput
    enabled: true
    opacity: editorLocked ? 0.55 : 1.0
    implicitHeight: inlineMode ? Math.max(80, _content.implicitHeight) + editorPad * 2 : 200

    Rectangle {
        visible: inlineMode
        anchors.fill: parent
        color: editorFill
        border.color: editorEdge
        border.width: editorBorderW
        radius: editorRadius
    }

    Rectangle {
        visible: inlineMode && showAccent && editorAccentW > 0
        width: editorAccentW
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Math.max(1, editorBorderW)
        color: editorAccent
    }

    function loadModel() {
        if (!backend || !uiState)
            return
        _root.inputItemModel = backend.getInputItem(
            uiState.currentInput,
            uiState.currentInputIndex
        )
    }

    Component.onCompleted: loadModel()
    onSequenceIndexChanged: loadModel()

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
        x: inlineMode ? editorPad : 0
        y: inlineMode ? editorPad : 0
        width: parent.width - (inlineMode ? editorPad * 2 : 0)
        spacing: 8

        Repeater {
            id: _inlineRepeater
            model: _root.inlineMode ? _root.inputItemModel : null

            delegate: Item {
                id: _inlineWrap
                required property int index
                required property var modelData
                Layout.fillWidth: true
                visible: _root.sequenceIndex < 0 || index === _root.sequenceIndex
                implicitHeight: visible ? _inlineBind.implicitHeight : 0
                height: implicitHeight

                InputItemBinding {
                    id: _inlineBind
                    width: parent.width
                    enabled: !editorLocked
                    compactMode: _root.compactMode
                    inputBinding: _inlineWrap.modelData
                    inputItemModel: _root.inputItemModel
                }
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
