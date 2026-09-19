// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Style

Rectangle {
    id: _card

    property string slug: ""
    property string cardName: ""
    property string rawName: ""
    property string guid: ""
    property string direction: "source"
    property string status: "Stub"
    property string bus: ""
    property int buttons: 0
    property int axes: 0
    property int hats: 0
    property string photo: ""
    property bool isStub: true
    property bool isModule: false
    property string tab: "physical"
    property string target: ""
    property string lastLine: ""
    property string lastHardware: ""
    property bool focused: false
    property bool pinActive: false
    property bool hoverPeek: true
    property int stackIndex: 0
    property bool lifting: false
    property bool resizing: false
    z: stackIndex + (lifting || resizing ? 100 : 0)

    signal cardFocused()
    signal openConfiguration()
    signal configureModule()
    signal pinControlDisplay()
    signal autoMap()
    signal openDeviceViewer()
    signal openPairing()
    signal openCalibration()
    signal openDeviceInformation()
    signal assignHardware()
    signal ignoreDevice()
    signal dropAt(real cx, real cy)
    signal sizeChanged(int w, int h)

    implicitHeight: _body.implicitHeight + 20
    radius: 4
    clip: true
    color: "#18181B"
    border.width: focused ? 2 : 1
    border.color: focused ? "#A1A1AA" : "#3F3F46"

    ColumnLayout {
        id: _body
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        Item {
            id: _photoWell
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 72
            Layout.preferredHeight: {
                if (_photo.status === Image.Ready && _photo.implicitWidth > 0) {
                    var ratio = _photo.implicitHeight / _photo.implicitWidth
                    return Math.round(Math.min(280, Math.max(96, width * ratio)))
                }
                return 120
            }

            Rectangle {
                anchors.fill: parent
                color: "#09090B"
                border.color: "#3F3F46"
                border.width: 1
                radius: 2

                Image {
                    id: _photo
                    anchors.fill: parent
                    anchors.margins: 2
                    source: photo
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: photo && photo.length
                    onStatusChanged: _photoWell.Layout.preferredHeightChanged()
                    onImplicitWidthChanged: _photoWell.Layout.preferredHeightChanged()
                }

                Label {
                    anchors.centerIn: parent
                    visible: !(photo && photo.length)
                    text: isStub ? "No module photo" : "No photo"
                    color: "#A1A1AA"
                    font.pixelSize: 11
                }

                Rectangle {
                    visible: pinActive || (hoverPeek && _hover.hovered)
                    anchors.fill: parent
                    color: "#AA14532D"
                    Label {
                        anchors.centerIn: parent
                        text: pinActive ? "Control Display pinned" : "Control Display"
                        color: "#BBF7D0"
                        font.pixelSize: 11
                    }
                }
            }

            HoverHandler { id: _hover }
        }

        Label {
            text: cardName
            color: "#E4E4E7"
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            text: status + " · " + bus
            color: "#A1A1AA"
            font.pixelSize: 11
        }

        Label {
            visible: isModule
            text: buttons + " buttons  " + axes + " axes  " + hats + " hats"
            color: "#E4E4E7"
            font.pixelSize: 11
        }

        Label {
            visible: target.length
            text: "→ " + target
            color: "#A1A1AA"
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            text: lastLine.length ? ("last: " + lastLine) : "last: —"
            color: "#E4E4E7"
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true

            HoverHandler { id: _lastHover }
            ToolTip.visible: _lastHover.hovered && lastHardware.length > 0
            ToolTip.text: lastHardware
            ToolTip.delay: 400
        }
    }

    MouseArea {
        id: _grab
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: _card.resizing ? null : _card
        drag.threshold: 10
        property bool didDrag: false
        enabled: !_card.resizing

        onPressed: function(mouse) {
            didDrag = false
            if (mouse.button === Qt.LeftButton)
                _card.lifting = true
        }
        onPositionChanged: {
            if (drag.active)
                didDrag = true
        }
        onReleased: function(mouse) {
            _card.lifting = false
            if (didDrag) {
                _card.dropAt(_card.x + _card.width / 2, _card.y + _card.height / 2)
                _card.x = 0
                _card.y = 0
            }
        }
        onClicked: function(mouse) {
            if (didDrag)
                return
            if (mouse.button === Qt.RightButton)
                _menu.popup()
            else
                _card.cardFocused()
        }
        onDoubleClicked: {
            if (!didDrag)
                _card.openConfiguration()
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        width: 20
        height: 20
        radius: 2
        z: 6
        color: _hideHover.hovered ? "#3F3F46" : "#00000000"
        border.color: "#3F3F46"
        border.width: 1

        Label {
            anchors.centerIn: parent
            text: "×"
            color: "#A1A1AA"
            font.pixelSize: 12
        }
        HoverHandler { id: _hideHover }
        MouseArea {
            anchors.fill: parent
            z: 7
            cursorShape: Qt.PointingHandCursor
            onClicked: _card.ignoreDevice()
        }
        ToolTip.visible: _hideHover.hovered
        ToolTip.text: "Hide device"
        ToolTip.delay: 400
    }


    function _clampW(w) { return Math.max(220, Math.min(720, w)) }
    function _clampH(h) { return Math.max(140, Math.min(520, h)) }

    MouseArea {
        id: _east
        z: 20
        width: 10
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 16
        cursorShape: Qt.SizeHorCursor
        onPressed: function() { _card.resizing = true; _card.lifting = false }
        onPositionChanged: function(mouse) {
            if (pressed)
                _card.width = _card._clampW(_card.width + mouse.x - width / 2)
        }
        onReleased: function() {
            _card.resizing = false
            _card.sizeChanged(Math.round(_card.width), Math.round(_card.height))
        }
    }
    MouseArea {
        id: _south
        z: 20
        height: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 16
        cursorShape: Qt.SizeVerCursor
        onPressed: function() { _card.resizing = true; _card.lifting = false }
        onPositionChanged: function(mouse) {
            if (pressed)
                _card.height = _card._clampH(_card.height + mouse.y - height / 2)
        }
        onReleased: function() {
            _card.resizing = false
            _card.sizeChanged(Math.round(_card.width), Math.round(_card.height))
        }
    }
    MouseArea {
        id: _corner
        z: 21
        width: 18
        height: 18
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        onPressed: function() { _card.resizing = true; _card.lifting = false }
        onPositionChanged: function(mouse) {
            if (pressed) {
                _card.width = _card._clampW(_card.width + mouse.x - width / 2)
                _card.height = _card._clampH(_card.height + mouse.y - height / 2)
            }
        }
        onReleased: function() {
            _card.resizing = false
            _card.sizeChanged(Math.round(_card.width), Math.round(_card.height))
        }
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: 10
            height: 10
            color: "#00000000"
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var c = getContext("2d")
                    c.clearRect(0, 0, width, height)
                    c.strokeStyle = "#A1A1AA"
                    c.lineWidth = 1.5
                    c.beginPath(); c.moveTo(2, 10); c.lineTo(10, 2); c.stroke()
                    c.beginPath(); c.moveTo(6, 10); c.lineTo(10, 6); c.stroke()
                }
            }
        }
    }

    Menu {
        id: _menu

        MenuItem { text: "Open Configuration"; onTriggered: _card.openConfiguration() }
        MenuItem {
            text: direction === "dest" ? "Configure output module" : "Configure input module"
            onTriggered: _card.configureModule()
        }
        MenuItem {
            visible: direction !== "dest"
            height: visible ? implicitHeight : 0
            text: pinActive ? "Unpin Control Display" : "Pin Control Display"
            onTriggered: _card.pinControlDisplay()
        }
        MenuItem { text: "Auto Map"; onTriggered: _card.autoMap() }
        MenuItem {
            visible: direction !== "dest"
            height: visible ? implicitHeight : 0
            text: "Device Viewer"
            onTriggered: _card.openDeviceViewer()
        }
        MenuItem { text: "Pairing-Viewer"; onTriggered: _card.openPairing() }
        MenuItem {
            visible: direction !== "dest"
            height: visible ? implicitHeight : 0
            text: "Calibration"
            onTriggered: _card.openCalibration()
        }
        MenuItem { text: "Device Information"; onTriggered: _card.openDeviceInformation() }
        MenuItem {
            visible: direction !== "dest"
            height: visible ? implicitHeight : 0
            text: "Assign hardware…"
            onTriggered: _card.assignHardware()
        }
        MenuSeparator {}
        MenuItem { text: "Ignore device"; onTriggered: _card.ignoreDevice() }
    }
}
