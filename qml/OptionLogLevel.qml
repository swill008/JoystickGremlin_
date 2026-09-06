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
                text: modelData
                checked: _model.level === modelData
                checkable: true
                onClicked: () => { _model.setLevel(modelData) }
            }
        }
    }
}
