// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Config

Item {
    id: _root

    implicitHeight: _combo.implicitHeight
    implicitWidth: 240

    OscOutputHostModel {
        id: _model
    }

    ComboBox {
        id: _combo

        anchors.fill: parent
        model: _model
        textRole: "name"
        editable: true
        selectTextByMouse: true
        currentIndex: _model.currentIndex
        implicitContentWidthPolicy: ComboBox.WidestText
        onActivated: (index) => { _model.currentIndex = index }
        onAccepted: () => { _model.setHost(editText) }

        Component.onCompleted: () => {
            if (_combo.contentItem && _combo.contentItem.editingFinished) {
                _combo.contentItem.editingFinished.connect(
                    () => { _model.setHost(_combo.editText) }
                )
            }
        }
    }
}
