// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Config

Item {
    id: _root

    implicitHeight: _row.implicitHeight
    implicitWidth: 280

    OscOutputHostModel {
        id: _model
    }

    RowLayout {
        id: _row

        anchors.fill: parent
        spacing: 6

        ComboBox {
            id: _combo

            Layout.fillWidth: true
            model: _model
            textRole: "name"
            currentIndex: _model.currentIndex
            implicitContentWidthPolicy: ComboBox.WidestText
            onActivated: (index) => { _model.currentIndex = index }
        }

        Button {
            Layout.preferredWidth: 36
            Layout.preferredHeight: _combo.height
            text: "\u21bb"
            ToolTip.visible: hovered
            ToolTip.text: "Rescan this PC's IP addresses"
            onClicked: () => { _model.refresh() }
        }
    }
}
