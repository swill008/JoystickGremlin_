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
    title: "Export devices"

    Shortcut { sequence: "Esc"; onActivated: {} }
    Shortcut { sequence: "Return"; onActivated: {} }
    Shortcut { sequence: "Enter"; onActivated: {} }
    color: Style.background
    Universal.theme: Style.theme

    property string deviceName: ""
    property string statusText: deviceName.length
        ? "Packs the module map and photos. GUID stays on this PC."
        : "Select a Home screen card first, then Export."

    HardwareProfile { id: _hw }

    function _chosenFile() {
        return Helpers.fileDialogUrl(_save)
    }

    FileDialog {
        id: _save
        title: "Export device pack"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "zip"
        nameFilters: ["Device packs (*.zip)"]
        onAccepted: {
            var dest = _chosenFile()
            if (!dest || !dest.length) {
                statusText = "Cannot write that path."
                return
            }
            var raw = _hw.exportMap(deviceName, dest)
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
        Label {
            text: deviceName.length ? deviceName : "—"
            color: deviceName.length ? Style.foreground : "#F87171"
        }

        Label {
            text: statusText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#A1A1AA"
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Cancel"; focusPolicy: Qt.NoFocus; onClicked: _win.close() }
            Button {
                text: "Export…"; focusPolicy: Qt.NoFocus
                enabled: deviceName.length > 0
                onClicked: {
                    var hint = _hw.defaultExportUrl(deviceName)
                    if (hint && hint.length) {
                        try { _save.selectedFile = hint } catch (e) {}
                        try { _save.currentFile = hint } catch (e) {}
                    }
                    _save.open()
                }
            }
        }
    }
}
