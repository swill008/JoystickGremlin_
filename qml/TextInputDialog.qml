// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Style

Window {
    id: _root

    minimumWidth: 200
    minimumHeight: 60

    color: Style.background
    Universal.theme: Style.theme
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    signal accepted(string value)
    property string text : "New text"
    property string lastAccepted: ""
    property var validator: function(value) { return true }
    property bool _clearedOnClick: false
    property bool _committed: false

    title: "Text Input Field"

    function seedText() {
        if (_root.text && _root.text.length > 0) {
            return _root.text
        }
        return lastAccepted
    }

    onVisibleChanged: {
        if (visible) {
            _committed = false
            _clearedOnClick = false
            _input.text = seedText()
            Qt.callLater(function() {
                if (_root.visible) {
                    _input.forceActiveFocus()
                }
            })
        } else if (!_committed) {
            lastAccepted = ""
        }
    }

    onActiveChanged: {
        if (visible && !active && !_committed) {
            visible = false
        }
    }

    onTextChanged: {
        _clearedOnClick = false
        if (visible) {
            _input.text = seedText()
        }
    }

    RowLayout {
        anchors.fill: parent

        JGTextField {
            id: _input

            Layout.fillWidth: true
            Layout.leftMargin: 5
            focus: true

            TapHandler {
                onTapped: {
                    if (!_root._clearedOnClick) {
                        _input.text = ""
                        _root._clearedOnClick = true
                        _input.forceActiveFocus()
                    }
                }
            }

            Keys.onEscapePressed: {
                _root._committed = false
                _root.visible = false
            }
            Keys.onReturnPressed: _button.click()
            Keys.onEnterPressed: _button.click()

            onTextEdited: () => {
                let isValid = _root.validator(text)
                _input.outlineOverride = isValid ? null : Style.error
                _button.enabled = isValid
            }
        }

        Button {
            id: _button

            Layout.rightMargin: 10

            text: "Ok"

            onClicked: () => {
                _root.lastAccepted = _input.text
                _root._committed = true
                _root.accepted(_input.text)
            }
        }
    }

}
