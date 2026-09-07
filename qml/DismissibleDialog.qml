// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Style

Popup {
    id: _root

    property string titleText: ""
    property string messageText: ""
    property string confirmText: "OK"
    property string cancelText: ""
    property bool destructive: false

    signal confirmed()
    signal cancelled()

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16

    onClosed: {
        if (!_accepted) {
            cancelled()
        }
        _accepted = false
    }

    property bool _accepted: false

    background: Rectangle {
        color: Style.background
        border.color: Style.accent
        border.width: 1
        radius: 4
    }

    contentItem: ColumnLayout {
        spacing: 12

        Label {
            text: _root.titleText
            font.bold: true
            font.pixelSize: 16
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Label {
            text: _root.messageText
            wrapMode: Text.WordWrap
            Layout.preferredWidth: 420
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Button {
                visible: _root.cancelText.length > 0
                text: _root.cancelText
                onClicked: {
                    _root.close()
                }
            }

            Button {
                text: _root.confirmText
                highlighted: !_root.destructive
                onClicked: {
                    _root._accepted = true
                    _root.confirmed()
                    _root.close()
                }
            }
        }
    }
}
