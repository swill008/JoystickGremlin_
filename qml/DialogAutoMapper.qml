// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Profile
import Gremlin.Tools
import Gremlin.Style
import Gremlin.Config

Window {
    minimumWidth: 900
    minimumHeight: 400

    color: Style.background
    Universal.theme: Style.theme

    title: "Auto Mapper"

    Shortcut { sequence: "Esc"; onActivated: {} }
    Shortcut { sequence: "Return"; onActivated: {} }
    Shortcut { sequence: "Enter"; onActivated: {} }

    DeviceListModel {
        id: _physicalDevices
        deviceType: "physical"
    }

    DeviceListModel {
        id: _virtualDevices
        deviceType: "virtual"
    }

    Tools {
        id: tools
    }

    // Properties to track the selected devices and user selections.
    property var selectedPhysicalDevices: ({})
    property var selectedVJoyDevices: ({})

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        RowLayout {
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.rightMargin: 10

                RowLayout {
                    Label {
                        text: "Input module"
                    }

                    LayoutHorizontalSpacer {
                        Layout.preferredHeight: 1
                        color: Style.accent
                    }
                }

                JGListView {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    model: _physicalDevices
                    scrollbarAlwaysVisible: true

                    delegate: CheckBox {
                        width: ListView.view.width - 10

                        text: model.name
                        checked: false

                        onCheckedChanged: () => {
                            selectedPhysicalDevices[model.guid] = checked
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    Label {
                        text: "Output module"
                    }

                    LayoutHorizontalSpacer {
                        Layout.preferredHeight: 1
                        color: Style.accent
                    }
                }

                JGListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    model: _virtualDevices
                    scrollbarAlwaysVisible: true

                    delegate: CheckBox {
                        width: ListView.view.width - 10

                        text: model.name
                        checked: false

                        onCheckedChanged: () => {
                            selectedVJoyDevices[model.vjoy_id] = checked
                        }
                    }
                }
            }
        }

        RowLayout {
            Label {
                text: "Select Mode"
            }

            ComboBox {
                id: _modeSelector

                model: ModeListModel {}

                textRole: "name"
            }

            LayoutHorizontalSpacer {}

            Switch {
                id: _overwriteNonEmpty

                text: "Overwrite used inputs"

                Component.onCompleted: checked = tools.lastOverwriteUsedInputs()
            }

            Switch {
                id: _repeatDevices

                text: "Repeat vJoy devices"

            }
        }

        RowLayout {
            Layout.topMargin: 10

            Button {
                text: "Create 1:1 mappings"

                onClicked: () => {
                    _statusMessage.text = tools.createMappings(
                        _modeSelector.currentText,
                        selectedPhysicalDevices,
                        selectedVJoyDevices,
                        _overwriteNonEmpty.checked,
                        _repeatDevices.checked
                    )

                    selectedPhysicalDevices = ({})
                    selectedVJoyDevices = ({})
                }
            }

            Label {
                id: _statusMessage

                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                text: "Select devices, options and then click the button."
            }

            IconButton {
                text: bsi.icons.help
                font.pixelSize: 24

                ToolTip {
                    text: "- Select mode to create bindings in.
- Select source physical devices and target vJoy devices.
- Click \"Create 1:1 mappings\" button.

Overwrite non-empty: Replaces existing mappings in the profile.
Repeat vJoy: Cycles through vJoy inputs, if needed to map all physical inputs."

                    visible: parent.hovered
                    delay: 500
                }
            }
        }
    }
}
