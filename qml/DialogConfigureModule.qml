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

    property string direction: "source"
    property string deviceName: ""
    property string deviceGuid: ""
    property string photoUrl: ""

    width: 980
    height: 640
    minimumWidth: 800
    minimumHeight: 480
    title: direction === "dest" ? "Configure output module" : "Configure input module"
    color: Style.background
    Universal.theme: Style.theme

    HardwareProfile { id: _hw }
    DriverInputModel { id: _driver }

    Component.onCompleted: {
        _driver.loadDevice(deviceGuid, deviceName)
        _win.photoUrl = _hw.profilePhotoUrl(deviceName)
    }

    FileDialog {
        id: _imageDialog
        title: "Import image"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: {
            var src = selectedFile && selectedFile.toString ? selectedFile.toString() : selectedFile
            if (!src || !String(src).length)
                src = currentFile
            var rel = _hw.copyImage(src, deviceName)
            var url = rel.length ? _hw.imageUrl(rel) : ""
            if (!url.length)
                url = _hw.profilePhotoUrl(deviceName)
            _win.photoUrl = url.length ? (url + "?t=" + Date.now()) : ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Label {
            text: deviceName.length ? deviceName : "Unnamed device"
            font.pixelSize: 16
            font.bold: true
        }

        Label {
            text: "Device is a name line. Marks and 5-ways stay on Button Map. Press a control to claim it; uncheck to undo."
            color: "#A1A1AA"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                color: "#18181B"
                border.color: "#3F3F46"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    Image {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        source: photoUrl
                        fillMode: Image.PreserveAspectFit
                        visible: photoUrl && photoUrl.length
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !(photoUrl && photoUrl.length)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        color: "#A1A1AA"
                        text: "No photo for this module.\nImport image…"
                    }
                    Button {
                        text: "Import image…"
                        onClicked: _imageDialog.open()
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: _list
                    anchors.fill: parent
                    clip: true
                    model: _driver
                    currentIndex: -1
                    highlightMoveDuration: 80
                    Connections {
                        target: _driver
                        function onRowActivated(row) {
                            _list.currentIndex = row
                            _list.positionViewAtIndex(row, ListView.Contain)
                        }
                    }
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 34
                        color: model.lit ? "#14532D" : (index === _list.currentIndex ? "#27272A" : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 8
                            spacing: 8

                        CheckBox {
                            checked: model.claimed
                            onClicked: {
                                if (checked)
                                    _driver.setClaimed(index, true)
                                else
                                    _driver.setClaimed(index, false)
                            }
                        }
                        Label {
                            text: model.label
                            Layout.preferredWidth: 120
                            color: model.lit ? "#BBF7D0" : Style.foreground
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: model.friendly
                            placeholderText: "Friendly name"
                            onEditingFinished: _driver.setFriendly(index, text)
                        }
                        }
                    }
                    ScrollBar.vertical: ScrollBar {}
                }
                Label {
                    anchors.centerIn: parent
                    visible: _list.count === 0
                    color: "#A1A1AA"
                    wrapMode: Text.WordWrap
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    text: deviceName.toLowerCase() === "keyboard"
                          ? "Press a key to add it."
                          : "No controls reported. For a stick, check DILL sees the device."
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "Import devices…"
                onClicked: {
                    var c = Qt.createComponent("DialogImportDevices.qml")
                    if (c.status === Component.Ready)
                        c.createObject(null, {}).show()
                }
            }
            Button {
                text: "Export devices…"
                onClicked: {
                    var c = Qt.createComponent("DialogExportDevices.qml")
                    if (c.status === Component.Ready)
                        c.createObject(null, {"deviceName": deviceName}).show()
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                onClicked: _win.close()
            }
            Button {
                text: "Save module"
                onClicked: {
                    if (_driver.saveClaim(deviceName, direction))
                        _win.close()
                }
            }
        }
    }
}
