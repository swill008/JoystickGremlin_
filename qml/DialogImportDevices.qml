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
import "helpers.js" as Helpers

Window {
    id: _win
    width: 560
    height: 320
    title: "Import devices"

    Shortcut { sequence: "Esc"; onActivated: {} }
    Shortcut { sequence: "Return"; onActivated: {} }
    Shortcut { sequence: "Enter"; onActivated: {} }
    color: Style.background
    Universal.theme: Style.theme

    property string zipUrl: ""
    property string statusText: "Pick a device pack zip first."
    property string packDevice: ""

    HardwareProfile { id: _hw }

    function _chosenFile() {
        return Helpers.fileDialogUrl(_pick)
    }

    FileDialog {
        id: _pick
        title: "Open device pack"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Device packs (*.zip)"]
        onAccepted: {
            zipUrl = _chosenFile()
            if (!zipUrl || !zipUrl.length) {
                statusText = "Could not read pack."
                packDevice = ""
                return
            }
            var raw = _hw.peekZip(zipUrl)
            try {
                var info = JSON.parse(raw)
            } catch (e) {
                statusText = "Could not read pack."
                packDevice = ""
                return
            }
            if (!info.ok) {
                statusText = info.error || "Invalid pack."
                packDevice = ""
                return
            }
            packDevice = info.device || ""
            statusText = packDevice.length
                ? ("Pack device: " + packDevice + "  (GUID is not in the zip; bind locally after import.)")
                : "Pack has no device name."
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.bottomMargin: 58
        spacing: 8

        Label {
            text: "Device"
            font.bold: true
        }
        Label {
            text: packDevice.length ? packDevice : "—"
            color: packDevice.length ? Style.foreground : "#F87171"
        }
        Label {
            text: statusText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#A1A1AA"
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Button { text: "Choose zip…"; focusPolicy: Qt.NoFocus; onClicked: _pick.open() }
            Item { Layout.fillWidth: true }
            Button { text: "Cancel"; focusPolicy: Qt.NoFocus; onClicked: _win.close() }
            Button {
                text: "Import"; focusPolicy: Qt.NoFocus
                enabled: zipUrl.length > 0 && packDevice.length > 0
                onClicked: {
                    var raw = _hw.importMap(zipUrl)
                    try {
                        var info = JSON.parse(raw)
                        statusText = info.ok ? ("Imported " + info.device) : (info.error || "Import failed")
                        if (info.ok)
                            _win.close()
                    } catch (e) {
                        statusText = "Import failed."
                    }
                }
            }
        }
    }

    DebugFileLine {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
