// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only
// Device-Configuration-Macro Change — grouped bindings catalog.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Config
import Gremlin.Device
import Gremlin.Style

Item {
    id: _root

    property Device device
    property var moduleModel: null
    property string claimDeviceName: ""
    property bool isOutput: false
    readonly property bool editorLocked: backend && backend.gremlinActive && !isOutput
    readonly property bool runtimeActive: !!(backend && backend.gremlinActive)

    BindingCatalogModel {
        id: _catalog
        guid: device ? device.guid : ""
        deviceName: _root.claimDeviceName
    }

    Connections {
        target: moduleModel
        function onClaimsChanged() { _catalog.reload() }
    }

    Connections {
        target: uiState
        function onModeChanged() {
            if (uiState)
                _catalog.setMode(uiState.currentMode)
        }
        function onDeviceChanged() {
            if (!uiState || editorLocked)
                return
            showHid(uiState.currentInputIndex)
        }
    }

    Component.onCompleted: {
        if (uiState)
            _catalog.setMode(uiState.currentMode)
    }

    DeviceLiveState {
        id: _liveState
        guid: device ? device.guid : ""
        deviceName: _root.claimDeviceName
        locked: editorLocked
        liveWhileActive: false
    }

    HighlightSpeedModel {
        id: _highlightSpeed
    }

    function showHid(hid) {
        if (editorLocked || hid < 0)
            return
        let row = _catalog.rowForDeviceIndex(hid)
        if (row < 0)
            return
        if (_list.currentIndex !== row)
            _list.currentIndex = row
        Qt.callLater(function() {
            _list.positionViewAtIndex(row, ListView.Contain)
        })
    }

    Connections {
        target: signal
        function onSetInputIndex(index) { showHid(index) }
        function onInputItemChanged(itemIndex) { _catalog.reload() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Type"; color: "#A1A1AA" }
            ComboBox {
                id: _typeBox
                Layout.preferredWidth: 180
                model: ["All types", "Map to vJoy", "Map to keyboard", "Map to mouse", "Map to Xbox", "Macro", "Change mode", "Other", "Unmapped"]
                onActivated: {
                    var tags = ["all", "vjoy", "keyboard", "mouse", "xbox", "macro", "mode", "other", "unmapped"]
                    _catalog.typeFilter = tags[currentIndex]
                }
            }
            Label { text: "Destination"; color: "#A1A1AA" }
            ComboBox {
                id: _destBox
                Layout.fillWidth: true
                model: _catalog.destChoices
                onActivated: {
                    _catalog.destFilter = currentText === "All devices" ? "all" : currentText
                }
            }
        }

        JGListView {
            id: _list
            Layout.fillWidth: true
            Layout.fillHeight: true
            scrollbarAlwaysVisible: true
            spacing: 4
            highlightFollowsCurrentItem: true
            highlightMoveDuration: {
                if (!_highlightSpeed)
                    return 150
                if (_highlightSpeed.speed === "Fast")
                    return 0
                if (_highlightSpeed.speed === "Medium")
                    return 70
                return 150
            }
            model: _catalog

            delegate: Item {
                id: _row
                required property int index
                required property string rowKind
                required property string name
                required property string summary
                required property string typeLabel
                required property string destLabel
                required property string kind
                required property int hwId
                required property int deviceIndex
                required property int bindingCount
                required property int indent
                width: ListView.view.width - 12
                height: rowKind === "leaf" ? 36 : 50

                readonly property bool isGroup: rowKind === "group" || rowKind === "unmapped"
                readonly property bool selected: index === _list.currentIndex
                property int liveStamp: _liveState.stamp
                property string inputKind: (liveStamp >= 0 && deviceIndex >= 0) ? _liveState.kindAt(deviceIndex) : ""
                property real liveValue: (liveStamp >= 0 && deviceIndex >= 0) ? _liveState.valueAt(deviceIndex) : 0
                readonly property bool ledOn: runtimeActive && (inputKind === "button" || inputKind === "hat") && liveValue > 0.5
                readonly property bool axisRow: kind === "axis"

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: indent * 22
                    radius: 3
                    border.width: selected ? 2 : 1
                    border.color: selected ? "#E4E4E7" : "#3F3F46"
                    color: {
                        if (ledOn)
                            return Qt.rgba(0.133, 0.773, 0.369, selected ? 0.55 : 0.28)
                        if (selected)
                            return "#27272A"
                        if (rowKind === "unmapped-header")
                            return "#18181B"
                        return "#111113"
                    }

                    Rectangle {
                        visible: axisRow && rowKind === "group"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        height: 5
                        color: "#3F3F46"
                        Rectangle {
                            width: Math.max(0, Math.min(parent.width, parent.width * ((liveValue + 1.0) * 0.5)))
                            height: parent.height
                            color: "#22C55E"
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Rectangle {
                            visible: kind === "button" || kind === "hat"
                            width: 10
                            height: 10
                            radius: 5
                            color: ledOn ? "#22C55E" : "#3F3F46"
                        }

                        Label {
                            text: rowKind === "leaf" ? typeLabel : name
                            color: "#E4E4E7"
                            font.bold: rowKind !== "leaf"
                            font.pixelSize: rowKind === "leaf" ? 12 : 13
                            elide: Text.ElideRight
                            Layout.preferredWidth: rowKind === "leaf" ? 160 : 180
                        }
                        Label {
                            text: rowKind === "leaf" ? destLabel : (rowKind === "unmapped-header" ? summary : (rowKind === "unmapped" ? "Not bound" : summary))
                            color: "#A1A1AA"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            wrapMode: Text.NoWrap
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !editorLocked && deviceIndex >= 0
                        onClicked: {
                            _list.currentIndex = index
                            _list.syncSelection()
                        }
                    }
                }
            }

            function syncSelection() {
                if (!uiState || !device || currentIndex < 0 || editorLocked)
                    return
                var hid = _catalog.deviceIndexAt(currentIndex)
                if (hid < 0)
                    return
                var ident = device.inputIdentifier(hid)
                if (!ident)
                    return
                uiState.setCurrentInput(ident, hid)
            }

            onCurrentIndexChanged: syncSelection()
        }

        Label {
            visible: _catalog.count === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: "#A1A1AA"
            horizontalAlignment: Text.AlignHCenter
            text: "This window only shows what the input module passes.\nRight-click the card → Configure input module, press the controls to claim, then Save module."
        }
    }
}
