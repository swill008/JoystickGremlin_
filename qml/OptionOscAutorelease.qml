// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Config

Item {
    id: _root

    implicitHeight: _col.implicitHeight
    implicitWidth: 420

    OscAutoreleaseModel {
        id: _model
    }

    ColumnLayout {
        id: _col

        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "ms"
            }

            TextField {
                id: _delay

                Layout.preferredWidth: 80
                text: _model.delayMs
                inputMethodHints: Qt.ImhDigitsOnly
                onEditingFinished: () => { _model.delayMs = text }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Button {
                text: "1/10s"
                onClicked: () => { _model.setPreset(100) }
            }
            Button {
                text: "1/4s"
                onClicked: () => { _model.setPreset(250) }
            }
            Button {
                text: "1/2s"
                onClicked: () => { _model.setPreset(500) }
            }
            Button {
                text: "3/4s"
                onClicked: () => { _model.setPreset(750) }
            }
            Button {
                text: "1s"
                onClicked: () => { _model.setPreset(1000) }
            }
        }
    }
}
