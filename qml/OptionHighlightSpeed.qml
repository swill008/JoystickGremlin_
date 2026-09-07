// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Config

Item {
    id: _root

    implicitHeight: _row.implicitHeight
    implicitWidth: 252

    HighlightSpeedModel {
        id: _model
    }

    RowLayout {
        id: _row

        anchors.fill: parent
        spacing: 6

        Repeater {
            model: ["Slow", "Medium", "Fast"]

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 80
                Layout.minimumWidth: 64

                text: modelData
                checked: _model && _model.speed === modelData
                checkable: true
                onClicked: () => {
                    if (_model) {
                        _model.setSpeed(modelData)
                    }
                }
            }
        }
    }
}
