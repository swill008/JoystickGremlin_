// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Config

Item {
    id: _root

    implicitHeight: _row.implicitHeight
    implicitWidth: 420

    LogLevelModel {
        id: _model
    }

    RowLayout {
        id: _row

        anchors.fill: parent
        spacing: 6

        Repeater {
            model: ["Off", "ALL", "Info", "Warning", "Error"]

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 78
                Layout.minimumWidth: 64

                text: modelData
                checked: _model && _model.level === modelData
                checkable: true
                onClicked: () => {
                    if (_model) {
                        _model.setLevel(modelData)
                    }
                }
            }
        }
    }
}
