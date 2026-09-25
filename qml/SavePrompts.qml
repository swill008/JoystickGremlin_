// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls

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
        anchors.centerIn: Overlay.overlay
        standardButtons: Dialog.Save | Dialog.Discard | Dialog.Cancel
        closePolicy: Popup.NoAutoClose
        contentItem: Label {
            text: _gate.detail
            wrapMode: Text.WordWrap
            width: 420
        }
        onAccepted: _gate.saveChosen()
        onDiscarded: _gate.discardChosen()
        onRejected: _gate.cancelled()
    }

    Dialog {
        id: _result
        property bool ok: true
        modal: true
        anchors.centerIn: Overlay.overlay
        standardButtons: Dialog.Ok
        onAccepted: _gate.acknowledged()
        contentItem: Label {
            id: _resultText
            wrapMode: Text.WordWrap
            width: 420
        }
    }
}
