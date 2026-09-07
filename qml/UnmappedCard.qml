// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Style

ColumnLayout {
    id: _root

    property string deviceGuid: ""
    property string title: ""
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: _inner.implicitHeight + 16
        color: "#101215"
        border.color: Style.medColor
        border.width: 1
        radius: 6

        RowLayout {
            id: _inner
            width: parent.width - 16
            x: 8
            y: 6
            spacing: 8

            JGText {
                text: title
                opacity: 0.75
                font.pointSize: 12
            }

            JGText {
                text: "No Map to vJoy"
                opacity: 0.45
                font.pointSize: 10
            }

            Item { Layout.fillWidth: true }
        }
    }
}
