// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Window {
    id: _win
    width: 720
    height: 640
    minimumWidth: 640
    minimumHeight: 480
    title: "Hardware Hide"
    color: Style.background
    Universal.theme: Style.theme

    HidHideModel {
        id: _hh
    }

    Timer {
        id: _sizeSave
        interval: 400
        repeat: false
        onTriggered: _hh.saveWindowSize(_win.width, _win.height)
    }

    Component.onCompleted: {
        var w = _hh.windowWidth
        var h = _hh.windowHeight
        if (w >= 640)
            width = w
        if (h >= 480)
            height = h
    }
    onWidthChanged: if (visible) _sizeSave.restart()
    onHeightChanged: if (visible) _sizeSave.restart()
    onClosing: _hh.saveWindowSize(width, height)

    function titleOf(row) {
        var n = (row && row.name) ? String(row.name) : ""
        var u = n.toUpperCase()
        if (!n || u.indexOf("HID\\") === 0 || u.indexOf("USB\\") === 0)
            return "HID-compliant game controller"
        return n
    }

    FileDialog {
        id: _pickPhoto
        title: "Device image"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp *.webp)", "All files (*)"]
        property string targetId: ""
        onAccepted: {
            if (targetId)
                _hh.setDevicePhoto(targetId, selectedFile.toString())
        }
    }

    FileDialog {
        id: _pickExe
        title: "Add a game or program"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Programs (*.exe)", "All files (*)"]
        onAccepted: {
            var url = selectedFile
            var path = url.toString()
            if (path.startsWith("file:///"))
                path = path.substring(8)
            path = path.replace(/\//g, "\\")
            _hh.addGame("", path)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: driverRow.implicitHeight + 20
            radius: 3
            color: "#111113"
            border.color: "#3F3F46"

            RowLayout {
                id: driverRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                spacing: 10
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    Layout.alignment: Qt.AlignVCenter
                    color: _hh.installed ? "#22C55E" : "#A1A1AA"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        color: "#E4E4E7"
                        text: _hh.installed ? "HiDHide driver found" : "HiDHide is not installed"
                    }
                    Label {
                        visible: _hh.driverVersion.length > 0
                        color: "#A1A1AA"
                        font.pixelSize: 11
                        text: _hh.driverVersion
                    }
                }
                Switch {
                    id: cloakSwitch
                    enabled: _hh.installed
                    checked: _hh.cloakOn
                    text: "HiDHide Enabled"
                    onClicked: {
                        _hh.setCloak(cloakSwitch.checked)
                        cloakSwitch.checked = Qt.binding(function() { return _hh.cloakOn })
                    }
                }
                Switch {
                    id: _gamingOnly
                    checked: _hh.gamingOnly
                    text: "Gaming devices only"
                    onClicked: _hh.setGamingOnly(_gamingOnly.checked)
                }
            }
        }

        Label {
            text: "Hardware Hide"
            color: "#E4E4E7"
            font.pixelSize: 16
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#A1A1AA"
                font.pixelSize: 12
                text: "HiDHide hides the selected controllers from other programs. This program does not install HiDHide. Click on Get HiDHide to download the program."
            }
            ColumnLayout {
                spacing: 6
                Button {
                    text: "Get HiDHide"
                    Layout.fillWidth: true
                    onClicked: _hh.openDownload()
                }
                Button {
                    text: "Test"
                    Layout.fillWidth: true
                    onClicked: _hh.openGameControllers()
                }
            }
        }

        Label {
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#A1A1AA"
            font.pixelSize: 12
            text: "HiDHide Enabled means HiDHide enforces the device list and the program list. Off means HiDHide is installed but HiDHide is not hiding anything."
        }

        Label {
            visible: !_hh.installed
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#A1A1AA"
            font.pixelSize: 12
            text: "Install HiDHide from the Nefarius releases page, then click Refresh. Gremlin will not download or bundle that installer."
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical
            handle: Rectangle {
                implicitWidth: 8
                implicitHeight: 10
                color: SplitHandle.pressed ? "#3F3F46" : (SplitHandle.hovered ? "#27272A" : "#18181B")
                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 3
                    radius: 1
                    color: "#71717A"
                }
            }

            ColumnLayout {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                SplitView.preferredHeight: 300
                SplitView.minimumHeight: 96
                spacing: 6

                Label {
                    text: "DEVICES"
                    color: "#A1A1AA"
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                }

                Label {
                    visible: _hh.lastError.length > 0
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: "#FCA5A5"
                    font.pixelSize: 12
                    text: _hh.lastError
                }

                Label {
                    visible: _hh.deviceCount === 0
                    text: _hh.installed ? "No HID devices reported." : "Device list needs the HiDHide driver."
                    color: "#A1A1AA"
                }

                ListView {
                    id: _devs
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 48
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: _hh.deviceCount
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        required property int index
                        width: ListView.view.width
                        height: 56
                        radius: 3
                        color: "#111113"
                        border.color: "#3F3F46"
                        property int _gen: _hh.generation
                        property var row: _gen >= 0 ? _hh.deviceAt(index) : ({})
                        property bool confirmed: !!(row && row.confirmed)
                        opacity: confirmed ? 0.55 : 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 3
                                color: "#09090B"
                                border.color: "#3F3F46"
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: row.photo || ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: !!(row.photo)
                                    asynchronous: true
                                    cache: true
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Label {
                                    text: titleOf(row)
                                    color: confirmed ? "#A1A1AA" : "#E4E4E7"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: {
                                        if (!row.canHide)
                                            return "Cannot hide (keyboard or mouse)"
                                        var bits = []
                                        if (row.openDenied)
                                            bits.push("Denied")
                                        if (confirmed)
                                            bits.push("Hidden")
                                        if (row.clientBlocked)
                                            bits.push("Client list")
                                        var prefix = bits.length ? bits.join(" · ") + "  " : ""
                                        return prefix + (row.instanceId || "")
                                    }
                                    color: confirmed ? "#71717A" : "#A1A1AA"
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                            Button {
                                text: row.photo ? "Change image" : "Add image"
                                onClicked: {
                                    _pickPhoto.targetId = row.instanceId
                                    _pickPhoto.open()
                                }
                            }
                            Switch {
                                id: hideSwitch
                                enabled: _hh.installed && row.canHide
                                checked: !!(row && row.session)
                                onClicked: {
                                    _hh.setDeviceHidden(row.instanceId, hideSwitch.checked)
                                    hideSwitch.checked = Qt.binding(function() { return !!(row && row.session) })
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                SplitView.preferredHeight: 200
                SplitView.minimumHeight: 120
                spacing: 6

                Label {
                    text: "Programs that have been added to the Mask"
                    color: "#A1A1AA"
                    font.pixelSize: 11
                }

                RowLayout {
                    Layout.fillWidth: true
                    Switch {
                        id: inverseSwitch
                        enabled: _hh.installed
                        checked: _hh.inverseOn
                        text: "Inverse"
                        onClicked: {
                            _hh.setInverse(inverseSwitch.checked)
                            inverseSwitch.checked = Qt.binding(function() { return _hh.inverseOn })
                        }
                    }
                }

                Label {
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: "#A1A1AA"
                    font.pixelSize: 12
                    text: "Inverse off: the list is an allow list. Inverse on: the list is a block list."
                }

                ListView {
                    id: _games
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 48
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: _hh.gameCount
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        required property int index
                        width: ListView.view.width
                        height: 44
                        radius: 3
                        color: "#111113"
                        border.color: "#3F3F46"
                        property var row: _hh.gameAt(index)
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Label {
                                    text: row.name
                                    color: "#E4E4E7"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: row.path
                                    color: "#A1A1AA"
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                            Button {
                                text: "Remove"
                                onClicked: _hh.removeGame(row.path)
                            }
                        }
                    }
                }

                Label {
                    visible: _hh.gameCount === 0
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: "#A1A1AA"
                    font.pixelSize: 12
                    text: _hh.inverseOn
                          ? "Add a program here to block it from the hidden sticks. Joystick Gremlin is not added to this list."
                          : "Add a program here to let it see the hidden sticks. Joystick Gremlin is allowed during this session. After Exit, HiDHide uses the list that was already in its Client."
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "Add game…"
                enabled: _hh.installed
                onClicked: _pickExe.open()
            }
            Button {
                text: "Refresh"
                onClicked: _hh.refresh()
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Close"
                onClicked: _win.close()
            }
        }
    }
}
