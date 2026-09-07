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

    property string deviceGuid
    property string title

    implicitHeight: _content.implicitHeight

    function computeButtonHeight() {
        let columns = Math.floor(
            Math.max(_button_grid.width, _button_grid.Layout.minimumWidth) /
            _button_grid.cellWidth
        )
        if (columns < 1) {
            columns = 1
        }
        let rows = Math.ceil(_button_grid.count / columns)
        return rows * _button_grid.cellHeight
    }

    function computeHatHeight(cellHeight) {
        return Math.ceil(_hat_grid.count / 2) * cellHeight
    }

    DeviceButtonState {
        id: _button_state

        guid: deviceGuid
    }

    DeviceHatState {
        id: _hat_state

        guid: deviceGuid
    }

    ColumnLayout {
        id: _content

        anchors.left: parent.left
        anchors.right: parent.right

        RowLayout {
            id: _header

            JGText {
                text: title + " - Buttons & Hats"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                height: 2
                color: Style.lowColor
            }
        }

        RowLayout {
            GridView {
                id: _button_grid

                Layout.fillWidth: true
                Layout.minimumWidth: 400
                Layout.preferredWidth: 600
                Layout.minimumHeight: computeButtonHeight()
                Layout.alignment: Qt.AlignTop

                boundsMovement: Flickable.StopAtBounds
                boundsBehavior: Flickable.StopAtBounds
                interactive: false

                cellWidth: 76
                cellHeight: 22

                model: _button_state
                delegate: Item {
                    required property int index
                    required property int identifier
                    required property bool value

                    width: _button_grid.cellWidth
                    height: _button_grid.cellHeight

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        spacing: 6

                        Rectangle {
                            width: 11
                            height: 11
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: value ? Style.accent : "transparent"
                            border.width: 2
                            border.color: value ? Style.accent : Style.lowColor
                        }

                        Text {
                            text: identifier
                            color: Style.foreground
                            font.pointSize: 10
                            font.family: "Segoe UI"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            GridView {
                id: _hat_grid

                Layout.fillWidth: true
                Layout.minimumWidth: 200
                Layout.preferredWidth: 200
                Layout.minimumHeight: computeHatHeight(cellHeight)
                Layout.alignment: Qt.AlignTop

                boundsMovement: Flickable.StopAtBounds
                boundsBehavior: Flickable.StopAtBounds

                cellWidth: 100
                cellHeight: 100

                model: _hat_state
                delegate: Component {
                    HatView {
                        required property int identifier
                        required property point value

                        height: _hat_grid.cellHeight - 20
                        width: _hat_grid.cellWidth - 20

                        text: identifier
                        currentValue: value
                    }
                }
            }
        }
    }

}
