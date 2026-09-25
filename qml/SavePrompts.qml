// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: _gate

    property string detail: "Changes on this screen are not saved. Leave without saving and they will be lost."
    signal saveChosen()
    signal discardChosen()
    signal cancelled()
    signal acknowledged()

    function ask() { _ask.open() }

    function announce(ok, message) {
        _result.title = ok ? "Saved" : "Save failed"
        _result.ok = ok
        _resultText.text = message
        _result.open()
    }

    Dialog {
        id: _ask
        modal: true
        title: "Unsaved changes"
        parent: Overlay.overlay
        width: 480
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        standardButtons: Dialog.Save | Dialog.Discard | Dialog.Cancel
        closePolicy: Popup.NoAutoClose
        contentItem: ColumnLayout {
            Label {
                text: _gate.detail
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.preferredWidth: 420
            }
        }
        onAccepted: _gate.saveChosen()
        onDiscarded: _gate.discardChosen()
        onRejected: _gate.cancelled()
    }

    Dialog {
        id: _result
        property bool ok: true
        modal: true
        parent: Overlay.overlay
        width: 480
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        standardButtons: Dialog.Ok
        onAccepted: _gate.acknowledged()
        contentItem: ColumnLayout {
            Label {
                id: _resultText
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.preferredWidth: 420
            }
        }
    }
}
