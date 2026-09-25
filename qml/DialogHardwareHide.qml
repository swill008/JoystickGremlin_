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
    title: "Hardware Hide"
    color: Style.background
    Universal.theme: Style.theme

    HidHideModel {
        id: _hh
    }

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
                text: "HidHide hides physical controllers from other programs so games only see vJoy and Xbox. Gremlin does not install HidHide. Hides last while Gremlin is running. On Exit we put HidHide back the way we found it."
            }
            Button {
                text: "Get HidHide"
                onClicked: _hh.openDownload()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 3
            color: "#111113"
            border.color: "#3F3F46"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: _hh.installed ? "#22C55E" : "#A1A1AA"
                }
                Label {
                    Layout.fillWidth: true
                    color: "#E4E4E7"
                    text: _hh.installed ? "HidHide driver found" : "HidHide is not installed"
                }
                Switch {
                    id: cloakSwitch
                    enabled: _hh.installed
                    checked: _hh.cloakOn
                    text: "Hide physical devices from games"
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
            visible: !_hh.installed
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#A1A1AA"
            font.pixelSize: 12
            text: "Install HidHide from the Nefarius releases page, then click Refresh. Gremlin will not download or bundle that installer."
        }

        Label {
            text: "DEVICES"
            color: "#A1A1AA"
            font.pixelSize: 11
            font.capitalization: Font.AllUppercase
        }

        ListView {
            id: _devs
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 180
            clip: true
            spacing: 6
            model: _hh.deviceCount
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
                        text: "Hide from games"
                        onClicked: {
                            _hh.setDeviceHidden(row.instanceId, hideSwitch.checked)
                            hideSwitch.checked = Qt.binding(function() { return !!(row && row.session) })
                        }
                    }
                }
            }
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
            text: _hh.installed ? "No HID devices reported." : "Device list needs the HidHide driver."
            color: "#A1A1AA"
        }

        Label {
            text: _hh.inverseOn
                  ? "GAMES AND PROGRAMS BLOCKED FROM HIDDEN DEVICES"
                  : "GAMES AND PROGRAMS THAT MAY SEE HIDDEN DEVICES"
            color: "#A1A1AA"
            font.pixelSize: 11
            font.capitalization: Font.AllUppercase
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
            Layout.preferredHeight: 140
            clip: true
            spacing: 6
            model: _hh.gameCount
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
                  : "Add a program here to let it see the hidden sticks. Joystick Gremlin is allowed during this session. After Exit, HidHide uses the list that was already in its Client."
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
