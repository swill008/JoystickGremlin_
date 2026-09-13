// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import Gremlin.Style

Item {
    id: _face

    property var host: null
    property int liveStamp: 0
    property var buttons: null
    property var axes: null
    property var hats: null

    readonly property real _pw: _img.paintedWidth
    readonly property real _ph: _img.paintedHeight
    readonly property real _ox: (_img.width - _pw) * 0.5
    readonly property real _oy: (_img.height - _ph) * 0.5

    function px(nx) { return _ox + nx * _pw }
    function py(ny) { return _oy + ny * _ph }

    function hwButton(id) { return host && host.hwButton ? host.hwButton(id) : 0 }
    function hwAxis(id) { return host && host.hwAxis ? host.hwAxis(id) : 0 }
    function hwHat(id) { return host && host.hwHat ? host.hwHat(id) : 0 }

    // Locked physical map on vkb_gladiator_rig.jpg (same grip, two poses).
    // ax/ay = control on the photo. lx/ly = label box.
    function btnSpot(id) {
        var t = {
            // Right pose — red trigger half / full
            1:  {ax: 0.655, ay: 0.250, lx: 0.80, ly: 0.210},
            2:  {ax: 0.655, ay: 0.268, lx: 0.80, ly: 0.268},
            // Left pose — red head button
            3:  {ax: 0.318, ay: 0.198, lx: 0.01, ly: 0.175},
            // Right pose — white cap
            4:  {ax: 0.618, ay: 0.168, lx: 0.80, ly: 0.120},
            // Right pose — lower grip white button
            5:  {ax: 0.628, ay: 0.430, lx: 0.80, ly: 0.420},
            // Left pose — 5-way immediately right of red (6 U, 7 R, 8 D, 9 L, 10 C)
            6:  {ax: 0.392, ay: 0.188, lx: 0.01, ly: 0.040},
            7:  {ax: 0.408, ay: 0.205, lx: 0.01, ly: 0.085},
            8:  {ax: 0.392, ay: 0.222, lx: 0.01, ly: 0.130},
            9:  {ax: 0.376, ay: 0.205, lx: 0.01, ly: 0.220},
            10: {ax: 0.392, ay: 0.205, lx: 0.16, ly: 0.005},
            // Left pose — top-right head 5-way (11 U, 12 R, 13 D, 14 L, 15 C)
            11: {ax: 0.448, ay: 0.118, lx: 0.52, ly: 0.005},
            12: {ax: 0.462, ay: 0.135, lx: 0.52, ly: 0.048},
            13: {ax: 0.448, ay: 0.152, lx: 0.52, ly: 0.090},
            14: {ax: 0.434, ay: 0.135, lx: 0.52, ly: 0.132},
            15: {ax: 0.448, ay: 0.135, lx: 0.52, ly: 0.174},
            // Left pose — silver side wheel 5-way (16 U, 17 R, 18 D, 19 L, 20 C)
            16: {ax: 0.378, ay: 0.348, lx: 0.01, ly: 0.300},
            17: {ax: 0.395, ay: 0.365, lx: 0.01, ly: 0.345},
            18: {ax: 0.378, ay: 0.382, lx: 0.01, ly: 0.390},
            19: {ax: 0.360, ay: 0.365, lx: 0.01, ly: 0.435},
            20: {ax: 0.378, ay: 0.365, lx: 0.01, ly: 0.480},
            // Right pose — ribbed paddle push / pull (not the red trigger)
            21: {ax: 0.688, ay: 0.238, lx: 0.80, ly: 0.325},
            22: {ax: 0.688, ay: 0.255, lx: 0.80, ly: 0.375},
            // Base En2 right knob clicks
            23: {ax: 0.668, ay: 0.785, lx: 0.80, ly: 0.740},
            24: {ax: 0.668, ay: 0.805, lx: 0.80, ly: 0.790},
            // Base En1 left knob clicks
            25: {ax: 0.582, ay: 0.772, lx: 0.32, ly: 0.860},
            26: {ax: 0.582, ay: 0.792, lx: 0.32, ly: 0.910},
            // Base pads mid / left / right
            27: {ax: 0.598, ay: 0.698, lx: 0.52, ly: 0.605},
            28: {ax: 0.558, ay: 0.708, lx: 0.32, ly: 0.640},
            29: {ax: 0.638, ay: 0.688, lx: 0.80, ly: 0.620}
        }
        return t[id] || null
    }
    function hasBtn(id) { return btnSpot(id) !== null }
    function hasAxis(id) { return axisSpot(id) !== null }
    function hasHat(id) { return hatSpot(id) !== null }
    function axisSpot(id) {
        var t = {
            // Gimbal X / Y / Z twist — one home as marked on the photo
            1: {ax: 0.430, ay: 0.575, lx: 0.01, ly: 0.560},
            2: {ax: 0.430, ay: 0.590, lx: 0.01, ly: 0.610},
            3: {ax: 0.430, ay: 0.605, lx: 0.01, ly: 0.660},
            // Base Z slider between En1 and En2
            4: {ax: 0.628, ay: 0.778, lx: 0.48, ly: 0.940}
        }
        return t[id] || null
    }
    function hatSpot(id) {
        var t = {
            // Open-head analog ministick — 8-way hat only
            1: {ax: 0.298, ay: 0.108, lx: 0.01, ly: 0.005}
        }
        return t[id] || null
    }

    Image {
        id: _img
        anchors.fill: parent
        source: Qt.resolvedUrl("images/vkb_gladiator_rig.jpg")
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        onStatusChanged: _face.relayout()
        onPaintedWidthChanged: _face.relayout()
        onPaintedHeightChanged: _face.relayout()
    }

    signal relayout()

    component Callout: Item {
        property real ax: 0.5
        property real ay: 0.5
        property real lx: 0.05
        property real ly: 0.05
        property string hw: ""
        property string dest: "—"
        property bool lit: false

        anchors.fill: parent
        z: 2

        Canvas {
            id: _line
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = lit ? "#86EFAC" : "#D4D4D8"
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(px(ax), py(ay))
                ctx.lineTo(px(lx) + 6, py(ly) + 10)
                ctx.stroke()
            }
            Connections {
                target: _face
                function onRelayout() { _line.requestPaint() }
                function onWidthChanged() { _line.requestPaint() }
                function onHeightChanged() { _line.requestPaint() }
            }
        }

        Rectangle {
            x: px(ax) - 4
            y: py(ay) - 4
            width: 8
            height: 8
            radius: 4
            color: lit ? "#22C55E" : "#F4F4F5"
            border.color: lit ? "#86EFAC" : "#A1A1AA"
        }

        Rectangle {
            x: px(lx) - (lx > 0.55 ? width - 8 : 0)
            y: py(ly)
            implicitWidth: _lab.implicitWidth + 12
            implicitHeight: _lab.implicitHeight + 8
            radius: 4
            color: lit ? "#14532D" : "#18181B"
            border.color: lit ? "#22C55E" : "#3F3F46"
            Text {
                id: _lab
                anchors.centerIn: parent
                color: lit ? "#BBF7D0" : "#E4E4E7"
                font.pixelSize: 11
                text: hw + "  →  " + dest
            }
        }
    }

    Repeater {
        model: _face.buttons
        Callout {
            required property int identifier
            required property string vjoyLabel
            visible: _face.hasBtn(identifier)
            ax: visible ? _face.btnSpot(identifier).ax : 0
            ay: visible ? _face.btnSpot(identifier).ay : 0
            lx: visible ? _face.btnSpot(identifier).lx : 0
            ly: visible ? _face.btnSpot(identifier).ly : 0
            hw: "HW " + identifier
            dest: vjoyLabel
            lit: _face.liveStamp, _face.hwButton(identifier) > 0.5
        }
    }

    Repeater {
        model: _face.axes
        Callout {
            required property int identifier
            required property string vjoyLabel
            visible: _face.hasAxis(identifier)
            ax: visible ? _face.axisSpot(identifier).ax : 0
            ay: visible ? _face.axisSpot(identifier).ay : 0
            lx: visible ? _face.axisSpot(identifier).lx : 0
            ly: visible ? _face.axisSpot(identifier).ly : 0
            hw: "HW Axis " + identifier
            dest: vjoyLabel
            lit: _face.liveStamp, Math.abs(_face.hwAxis(identifier)) > 0.12
        }
    }

    Repeater {
        model: _face.hats
        Callout {
            required property int identifier
            required property string vjoyLabel
            visible: _face.hasHat(identifier)
            ax: visible ? _face.hatSpot(identifier).ax : 0
            ay: visible ? _face.hatSpot(identifier).ay : 0
            lx: visible ? _face.hatSpot(identifier).lx : 0
            ly: visible ? _face.hatSpot(identifier).ly : 0
            hw: "HW Hat " + identifier
            dest: vjoyLabel
            lit: _face.liveStamp, _face.hwHat(identifier) > 0.5
        }
    }
}
