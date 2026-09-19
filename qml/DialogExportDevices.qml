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
    height: 400
    title: "Export devices"
    color: Style.background
    Universal.theme: Style.theme

    property string deviceName: ""
    property bool sliceImage: true
    property bool sliceWiring: false
    property bool sliceMacros: false
    property bool sliceModes: false
    property bool sliceOutput: false
    property string statusText: "Device is exported as a name line. No GUID is written into the zip."

    HardwareProfile { id: _hw }

    FileDialog {
        id: _save
        title: "Export device pack"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "zip"
        nameFilters: ["Device packs (*.zip)"]
        onAccepted: {
            var raw = _hw.exportMap(deviceName, currentFile)
            try {
                var info = JSON.parse(raw)
                statusText = info.ok ? ("Wrote " + info.path) : (info.error || "Export failed")
                if (info.ok)
                    _win.close()
            } catch (e) {
                statusText = "Export failed."
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label { text: "Device"; font.bold: true }
        Label { text: deviceName.length ? deviceName : "—" }

        CheckBox { text: "Image"; checked: sliceImage; onToggled: sliceImage = checked }
        CheckBox { text: "Wiring"; checked: sliceWiring; onToggled: sliceWiring = checked }
        CheckBox { text: "Macros"; checked: sliceMacros; onToggled: sliceMacros = checked }
        CheckBox { text: "Modes"; checked: sliceModes; onToggled: sliceModes = checked }
        CheckBox { text: "Output"; checked: sliceOutput; onToggled: sliceOutput = checked }

        Label {
            text: statusText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#A1A1AA"
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Cancel"; onClicked: _win.close() }
            Button {
                text: "Export…"
                enabled: deviceName.length > 0
                onClicked: {
                    var hint = _hw.defaultExportUrl(deviceName)
                    if (hint && hint.length)
                        _save.currentFile = hint
                    _save.open()
                }
            }
        }
    }
}
