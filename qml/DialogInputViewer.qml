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

    function displayName(guid, hardwareName) {
        if (!_names) {
            return hardwareName
        }
        return _names.display(guid, hardwareName)
    }

    Connections {
        target: _inputViewer

        function onClosing() {
            _stateDisplay.children.forEach((child) => {
                child.destroy()
            })
            _deviceData.destroy()
            backend.resumeInputHighlighting()
        }
    }

    Component.onCompleted: () => {
        backend.pauseInputHighlighting()
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
        x: 24
        y: 24

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
            Layout.alignment: Qt.AlignTop
            Layout.rightMargin: 10
            Layout.minimumWidth: 250
            Layout.maximumWidth: 400
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent

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

                anchors.left: parent.left
                anchors.right: parent.right
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

            property var widget_btn_hat
            property var widget_axis_temp
            property var widget_axis_cur

            RowLayout {
                IconButton {
                    id: _foldButton

                    checkable: true
                    checked: false
                    text: checked ? bsi.icons.folded : bsi.icons.unfolded
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(_nameLabel.implicitHeight, 20)

                    Label {
                        id: _nameLabel
                        anchors.fill: parent
                        text: shownName
                        color: Style.foreground
                        font.pointSize: 12
                        font.family: "Segoe UI"
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: {
                            _inputViewer.hardwareTip = name
                            var pos = mapToItem(Overlay.overlay, 12, height + 4)
                            _hardwareTip.x = pos.x
                            _hardwareTip.y = pos.y
                        }
                        onExited: {
                            if (_inputViewer.hardwareTip === name) {
                                _inputViewer.hardwareTip = ""
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: _foldButton.checked

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
                        } else {
                            widget_axis_temp.destroy()
                        }
                    }
                }
                Switch {
                    text: "Axes - Current"

                    onClicked: () => {
                        if(checked) {
                            widget_axis_cur = create_widget(
                                "AxesStateCurrent.qml",
                                guid,
                                shownName
                            )
                        } else {
                            widget_axis_cur.destroy()
                        }
                    }
                }
                Switch {
                    text: "Buttons & Hats"

                    onClicked: () => {
                        if(checked) {
                            widget_btn_hat = create_widget(
                                "ButtonState.qml",
                                guid,
                                shownName
                            )
                        } else {
                            widget_btn_hat.destroy()
                        }
                    }
                }
            }
        }
    }
}
