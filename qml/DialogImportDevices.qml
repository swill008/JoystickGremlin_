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
    width: 560
    height: 420
    title: "Import devices"
    color: Style.background
    Universal.theme: Style.theme

    property string zipUrl: ""
    property string statusText: "Pick a device pack zip first."
    property string packDevice: ""
    property bool sliceImage: true
    property bool sliceWiring: false
    property bool sliceMacros: false
    property bool sliceModes: false
    property bool sliceOutput: false

    HardwareProfile { id: _hw }

    FileDialog {
        id: _pick
        title: "Open device pack"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Device packs (*.zip)"]
        onAccepted: {
            zipUrl = currentFile
            var raw = _hw.peekZip(currentFile)
            try {
                var info = JSON.parse(raw)
            } catch (e) {
                statusText = "Could not read pack."
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
        spacing: 8

        Label {
            text: "Device"
            font.bold: true
        }
        Label {
            text: packDevice.length ? packDevice : "— (mandatory name line, never a checkbox)"
            color: packDevice.length ? Style.foreground : "#F87171"
        }
        Label {
            text: statusText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#A1A1AA"
        }

        CheckBox { text: "Image"; checked: sliceImage; onToggled: sliceImage = checked }
        CheckBox { text: "Wiring"; checked: sliceWiring; onToggled: sliceWiring = checked }
        CheckBox { text: "Macros"; checked: sliceMacros; onToggled: sliceMacros = checked }
        CheckBox { text: "Modes (this device only)"; checked: sliceModes; onToggled: sliceModes = checked }
        CheckBox { text: "Output (dest stub layout)"; checked: sliceOutput; onToggled: sliceOutput = checked }

        Item { Layout.fillHeight: true }

        RowLayout {
            Button { text: "Choose zip…"; onClicked: _pick.open() }
            Item { Layout.fillWidth: true }
            Button { text: "Cancel"; onClicked: _win.close() }
            Button {
                text: "Import"
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
}
