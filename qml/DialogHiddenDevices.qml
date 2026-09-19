// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Window {
    id: _win
    width: 420
    height: 360
    title: "Hidden devices"
    color: Style.background
    Universal.theme: Style.theme

    property var moduleModel: null

    ListView {
        id: _list
        anchors.fill: parent
        anchors.margins: 12
        model: moduleModel ? moduleModel.hiddenList() : []
        delegate: RowLayout {
            width: ListView.view.width
            Label { text: modelData; Layout.fillWidth: true; color: Style.foreground }
            Button {
                text: "Show"
                onClicked: {
                    if (moduleModel)
                        moduleModel.unignoreSlug(modelData)
                    _list.model = moduleModel.hiddenList()
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: _list.count === 0
        text: "No hidden devices."
        color: "#A1A1AA"
    }
}
