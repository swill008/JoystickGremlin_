// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

ApplicationWindow {
    id: _win

    width: 1200
    height: 760
    minimumWidth: 960
    minimumHeight: 560
    title: deviceName.length ? ("Action Editor — " + deviceName) : "Action Editor"
    color: Style.background
    Universal.theme: Style.theme

    property var device: null
    property string deviceName: ""
    property int startHid: -1
    property int currentHid: -1

    function openFor(name, dev, hid) {
        deviceName = name || ""
        device = dev
        startHid = hid
        _controls.guid = device ? device.guid : ""
        _controls.deviceName = deviceName
        _controls.reload()
        show()
        raise()
        requestActivate()
        selectHid(hid)
    }

    function selectHid(hid) {
        currentHid = hid
        if (!uiState || !device || hid < 0)
            return
        var ident = device.inputIdentifier(hid)
        if (ident)
            uiState.setCurrentInput(ident, hid)
    }

    BindingCatalogModel {
        id: _controls
        guid: _win.device ? _win.device.guid : ""
        deviceName: _win.deviceName
    }

    Component.onCompleted: {
        signal.advancedEditorChanged(true)
        _controls.reload()
        if (startHid >= 0)
            selectHid(startHid)
    }

    onClosing: signal.advancedEditorChanged(false)

    menuBar: MenuBar {
        Menu {
            title: "File"
            MenuItem {
                text: "Close"
                onTriggered: _win.close()
            }
        }
        Menu {
            title: "Help"
            MenuItem {
                text: "Edits the open profile"
                enabled: false
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        ListView {
            id: _inputs
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            clip: true
            model: _controls
            delegate: Item {
                required property int index
                required property string rowKind
                required property string name
                required property int deviceIndex
                width: _inputs.width
                height: (rowKind === "group" || rowKind === "unmapped") ? 36 : 0
                visible: height > 0

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: deviceIndex === _win.currentHid ? "#1E3A5F" : "transparent"
                }
                Label {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: name
                    color: Style.foreground
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: _win.selectHid(deviceIndex)
                }
            }
        }

        InputConfiguration {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
