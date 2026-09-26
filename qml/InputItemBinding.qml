// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models

import QtQuick.Controls.Universal

import Gremlin.ActionPlugins
import Gremlin.Profile


Item {
    id: _root

    property InputItemBindingModel inputBinding
    property InputItemModel inputItemModel
    property bool hideControlSetup: false
    property InputItemBindingConfigurationHeader headerWidget: _header

    implicitHeight: _content.height

    Connections {
        target: signal

        function onReloadCurrentInputItem()
        {
            // Currently unused
        }
    }


    // Content
    ColumnLayout {
        id: _content

        anchors.left: parent.left
        anchors.right: parent.right

        // +--------------------------------------------------------------------
        // | Header
        // +--------------------------------------------------------------------
        InputItemBindingConfigurationHeader {
            id: _header

            Layout.fillWidth: true
            Layout.leftMargin: 5
            Layout.rightMargin: 20

            inputBinding: _root.inputBinding
            inputItemModel: _root.inputItemModel
            hideControlSetup: _root.hideControlSetup
        }

        // +--------------------------------------------------------------------
        // | Render the root action node
        // +--------------------------------------------------------------------
        RootActionNode {
            id: _action_node

            Layout.fillWidth: true
            Layout.rightMargin: 20

            action: _root.inputBinding.rootAction
        }

        HorizontalDivider {
            Layout.fillWidth: true
            Layout.leftMargin: 5
            Layout.rightMargin: 20

            spacing: 15
        }
    }
}