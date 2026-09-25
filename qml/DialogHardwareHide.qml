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
                    enabled: _hh.installed
                    checked: _hh.cloakOn
                    text: "Hide physical devices from games"
                    onToggled: {
                        if (!_hh.setCloak(checked))
                            checked = _hh.cloakOn
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
                property var row: _hh.deviceAt(index)
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
                            color: "#E4E4E7"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: row.canHide ? (row.instanceId || "") : "Cannot hide (keyboard or mouse)"
                            color: "#A1A1AA"
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
                        enabled: _hh.installed && row.canHide
                        checked: !!row.hidden
                        text: "Hide from games"
                        onToggled: {
                            if (!_hh.setDeviceHidden(row.instanceId, checked))
                                checked = !!row.hidden
                        }
                    }
                }
            }
        }

        Label {
            visible: _hh.deviceCount === 0
            text: _hh.installed ? "No HID devices reported." : "Device list needs the HidHide driver."
            color: "#A1A1AA"
        }

        Label {
            text: "GAMES AND PROGRAMS THAT MAY SEE HIDDEN DEVICES"
            color: "#A1A1AA"
            font.pixelSize: 11
            font.capitalization: Font.AllUppercase
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
            text: "Add each game exe that should still see the real controllers while Gremlin is running. After Exit, HidHide uses the lists that were already in its Client. Gremlin is allowed to see hidden devices during this session."
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
