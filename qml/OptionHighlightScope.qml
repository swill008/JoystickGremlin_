// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Config

Item {
    id: _root

    implicitHeight: _row.implicitHeight
    implicitWidth: 220

    HighlightScopeModel {
        id: _model
    }

    RowLayout {
        id: _row

        anchors.fill: parent
        spacing: 6

        Repeater {
            model: ["This tab", "Any device"]

            Button {
                Layout.fillWidth: true
                Layout.preferredWidth: 104
                Layout.minimumWidth: 84

                text: modelData
                checked: _model && _model.scope === modelData
                checkable: true
                onClicked: () => {
                    if (_model) {
                        _model.setScope(modelData)
                    }
                }
            }
        }
    }
}
