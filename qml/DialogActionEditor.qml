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
    color: Style.background
    Universal.theme: Style.theme

    property var device: null
    property string deviceName: ""
    property int startHid: -1
    property int currentHid: -1
    property bool singleControl: false
    property string controlName: ""
    property string controlSummary: ""

    title: {
        if (singleControl && controlName.length)
            return "Action Editor — " + controlName
        if (deviceName.length)
            return "Action Editor — " + deviceName
        return "Action Editor"
    }

    function openFor(name, dev, hid, single) {
        deviceName = name || ""
        device = dev
        singleControl = single === true
        startHid = hid
        _controls.guid = device ? device.guid : ""
        _controls.deviceName = deviceName
        _controls.reload()
        show()
        raise()
        requestActivate()
        if (singleControl)
            selectHid(hid)
        else
            selectFirst()
    }

    function selectFirst() {
        var count = _controls.rowCount()
        for (var i = 0; i < count; i++) {
            var kind = _controls.rowKindAt(i)
            if (kind === "group" || kind === "unmapped") {
                selectHid(_controls.deviceIndexAt(i))
                return
            }
        }
        currentHid = -1
        refreshHeader()
    }

    function selectHid(hid) {
        currentHid = hid
        refreshHeader()
        if (!uiState || !device || hid < 0)
            return
        var ident = device.inputIdentifier(hid)
        if (ident)
            uiState.setCurrentInput(ident, hid)
    }

    function refreshHeader() {
        controlName = currentHid >= 0 ? _controls.controlLabel(currentHid) : ""
        controlSummary = currentHid >= 0 ? _controls.controlSummary(currentHid) : ""
    }

    function sectionTitle(kind) {
        if (kind === "axis")
            return "Axes"
        if (kind === "hat")
            return "Hats"
        if (kind === "button")
            return "Buttons"
        return ""
    }

    BindingCatalogModel {
        id: _controls
        guid: _win.device ? _win.device.guid : ""
        deviceName: _win.deviceName
    }

    Component.onCompleted: {
        signal.advancedEditorChanged(true)
        _controls.reload()
        if (singleControl && startHid >= 0)
            selectHid(startHid)
        else
            selectFirst()
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
                text: singleControl ? "This window edits one control" : "This window edits the whole device"
                enabled: false
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ListView {
            id: _inputs
            visible: !_win.singleControl
            Layout.preferredWidth: _win.singleControl ? 0 : 280
            Layout.fillHeight: true
            clip: true
            model: _controls
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            section.property: "kind"
            section.criteria: ViewSection.FullString
            section.delegate: Label {
                width: _inputs.width
                leftPadding: 8
                text: _win.sectionTitle(section)
                color: "#9AA4B2"
                font.pixelSize: 11
                font.bold: true
                visible: text.length > 0
                height: visible ? 22 : 0
            }

            delegate: Item {
                required property int index
                required property string rowKind
                required property string name
                required property string destLabel
                required property string kind
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
                    anchors.left: parent.left
                    anchors.right: _dest.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: name
                    color: Style.foreground
                    elide: Text.ElideRight
                }
                Label {
                    id: _dest
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 120)
                    visible: rowKind === "group" && destLabel.length > 0
                    text: destLabel
                    color: "#9AA4B2"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !_win.singleControl
                    onClicked: _win.selectHid(deviceIndex)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Label {
                text: _win.controlName.length ? _win.controlName : "Select a control"
                color: Style.foreground
                font.pixelSize: 18
                font.bold: true
            }
            Label {
                visible: _win.controlSummary.length > 0
                text: _win.controlSummary
                color: "#9AA4B2"
                font.pixelSize: 12
            }

            InputConfiguration {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
