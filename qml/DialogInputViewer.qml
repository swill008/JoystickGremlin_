// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Window {
    id: _inputViewer

    width: 1400
    height: 800
    minimumWidth: 900
    minimumHeight: 500

    color: Style.background
    Universal.theme: Style.theme

    title: "Input Viewer"

    property string hardwareTip: ""

    DeviceNames { id: _names }
    PairDeviceModel { id: _pairs }

    function displayName(guid, hardwareName) {
        if (!_names) {
            return hardwareName
        }
        return _names.display(guid, hardwareName)
    }

    Connections {
        target: _inputViewer

        function onClosing() {
            _deviceData.destroy()
            backend.resumeInputHighlighting()
        }
    }

    Component.onCompleted: () => {
        backend.pauseInputHighlighting()
        if (_pairs) {
            _pairs.reload()
        }
    }

    DeviceListModel {
        id: _deviceData

        deviceType: "all"
    }

    function create_widget(qml_path, guid, name) {
        let component = Qt.createComponent(Qt.resolvedUrl(qml_path))
        if (component.status == Component.Ready) {
            var widget = component.createObject(
                _stateDisplay,
                {
                    deviceGuid: guid,
                    title: name,
                    "Layout.fillWidth": true
                }
            );
        }

        return widget
    }

    Popup {
        id: _hardwareTip

        visible: _inputViewer.hardwareTip.length > 0
        modal: false
        focus: false
        padding: 8
        closePolicy: Popup.NoAutoClose
        parent: Overlay.overlay

        background: Rectangle {
            color: Style.background
            border.color: Style.accent
            border.width: 1
            radius: 3
        }

        contentItem: Label {
            text: _inputViewer.hardwareTip
            color: Style.foreground
            font.pointSize: 11
        }
    }

    RowLayout {
        id: _root

        anchors.fill: parent

        ScrollView {
            id: _deviceScroll
            Layout.alignment: Qt.AlignTop
            Layout.rightMargin: 10
            Layout.minimumWidth: 280
            Layout.preferredWidth: 320
            Layout.maximumWidth: 400
            Layout.fillHeight: true

            ColumnLayout {
                width: Math.max(_deviceScroll.availableWidth, 280)

                Repeater {
                    model: _deviceData
                    delegate: _deviceDelegate
                }
            }
        }

        ScrollView  {
            id: _dynamicScroll

            Layout.fillWidth: true
            Layout.fillHeight: true

            Component.onCompleted: () => {
                _dynamicScroll.contentItem.boundsMovement = Flickable.StopAtBounds
                _dynamicScroll.contentItem.boundsBehavior = Flickable.StopAtBounds
            }

            ColumnLayout {
                id: _stateDisplay

                width: Math.max(_dynamicScroll.availableWidth, 700)
                spacing: 12

                Repeater {
                    model: _pairs
                    delegate: InputViewerCard {
                        required property string guid
                        required property string name
                        required property string pairLabel

                        Layout.fillWidth: true
                        deviceGuid: guid
                        title: name
                        pairLabel: pairLabel
                    }
                }
            }
        }
    }

    Component {
        id: _deviceDelegate

        ColumnLayout {
            id: _delegateContent

            required property int index
            required property string name
            required property string guid

            readonly property string shownName: _inputViewer.displayName(guid, name)
            readonly property bool hasFriendlyName: shownName !== name
            Layout.fillWidth: true

            property var widget_axis_temp

            RowLayout {
                Layout.fillWidth: true

                IconButton {
                    id: _foldButton

                    checkable: true
                    checked: false
                    text: checked ? bsi.icons.folded : bsi.icons.unfolded
                }

                Label {
                    id: _nameLabel
                    Layout.fillWidth: true
                    text: shownName
                    color: Style.foreground
                    font.pointSize: 12
                    font.family: "Segoe UI"
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3

                    HoverHandler {
                        id: _hover
                        onHoveredChanged: {
                            if (hovered && hasFriendlyName) {
                                _inputViewer.hardwareTip = name
                                var pos = _nameLabel.mapToItem(Overlay.overlay, 8, _nameLabel.height + 4)
                                _hardwareTip.x = pos.x
                                _hardwareTip.y = pos.y
                            } else if (_inputViewer.hardwareTip === name) {
                                _inputViewer.hardwareTip = ""
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: _foldButton.checked
                Layout.fillWidth: true
                Layout.leftMargin: _foldButton.width

                Switch {
                    text: "Axes - Temporal"

                    onClicked: () => {
                        if(checked) {
                            widget_axis_temp = create_widget(
                                "AxesStateSeries.qml",
                                guid,
                                shownName
                            )
                        } else if (widget_axis_temp) {
                            widget_axis_temp.destroy()
                        }
                    }
                }
            }
        }
    }
}
