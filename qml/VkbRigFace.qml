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

    function plusCell(hatAx, hatAy, cx, cy, dir) {
        var dx = 0.128
        var dy = 0.040
        var lx = cx
        var ly = cy
        if (dir === "up") ly = cy - dy
        else if (dir === "down") ly = cy + dy
        else if (dir === "left") lx = cx - dx
        else if (dir === "right") lx = cx + dx
        var isCenter = (dir === "center")
        return {ax: hatAx, ay: hatAy, lx: lx, ly: ly, line: isCenter, dot: isCenter}
    }

    function pairCell(ax, ay, lx, ly0, which, count) {
        var dy = 0.038
        var ly = ly0 + which * dy
        return {ax: ax, ay: ay, lx: lx, ly: ly, line: which === 0, dot: which === 0}
    }

    function btnSpot(id) {
        var t = {
            1:  pairCell(0.655, 0.259, 0.835, 0.300, 0),
            2:  pairCell(0.655, 0.259, 0.835, 0.300, 1),
            3:  {ax: 0.318, ay: 0.198, lx: 0.012, ly: 0.255},
            4:  {ax: 0.618, ay: 0.168, lx: 0.835, ly: 0.085},
            5:  {ax: 0.628, ay: 0.430, lx: 0.835, ly: 0.430},
            6:  plusCell(0.392, 0.205, 0.145, 0.175, "up"),
            7:  plusCell(0.392, 0.205, 0.145, 0.175, "right"),
            8:  plusCell(0.392, 0.205, 0.145, 0.175, "down"),
            9:  plusCell(0.392, 0.205, 0.145, 0.175, "left"),
            10: plusCell(0.392, 0.205, 0.145, 0.175, "center"),
            11: plusCell(0.448, 0.135, 0.145, 0.048, "up"),
            12: plusCell(0.448, 0.135, 0.145, 0.048, "right"),
            13: plusCell(0.448, 0.135, 0.145, 0.048, "down"),
            14: plusCell(0.448, 0.135, 0.145, 0.048, "left"),
            15: plusCell(0.448, 0.135, 0.145, 0.048, "center"),
            16: plusCell(0.378, 0.365, 0.145, 0.330, "up"),
            17: plusCell(0.378, 0.365, 0.145, 0.330, "right"),
            18: plusCell(0.378, 0.365, 0.145, 0.330, "down"),
            19: plusCell(0.378, 0.365, 0.145, 0.330, "left"),
            20: plusCell(0.378, 0.365, 0.145, 0.330, "center"),
            21: pairCell(0.688, 0.246, 0.835, 0.200, 0),
            22: pairCell(0.688, 0.246, 0.835, 0.200, 1),
            23: pairCell(0.668, 0.795, 0.835, 0.740, 0),
            24: pairCell(0.668, 0.795, 0.835, 0.740, 1),
            25: pairCell(0.582, 0.782, 0.145, 0.860, 0),
            26: pairCell(0.582, 0.782, 0.145, 0.860, 1),
            27: {ax: 0.598, ay: 0.698, lx: 0.560, ly: 0.605},
            28: {ax: 0.558, ay: 0.708, lx: 0.400, ly: 0.605},
            29: {ax: 0.638, ay: 0.688, lx: 0.720, ly: 0.605}
        }
        return t[id] || null
    }
    function hasBtn(id) { return btnSpot(id) !== null }
    function hasAxis(id) { return axisSpot(id) !== null }
    function hasHat(id) { return hatSpot(id) !== null }
    function spotOn(id, key, fallback) {
        var s = btnSpot(id)
        if (!s || s[key] === undefined) {
            return fallback
        }
        return s[key]
    }
    function axisSpot(id) {
        var t = {
            1: {ax: 0.430, ay: 0.590, lx: 0.012, ly: 0.520, line: true, dot: true},
            2: {ax: 0.430, ay: 0.590, lx: 0.012, ly: 0.558, line: false, dot: false},
            3: {ax: 0.430, ay: 0.590, lx: 0.012, ly: 0.596, line: false, dot: false},
            4: {ax: 0.628, ay: 0.778, lx: 0.500, ly: 0.940}
        }
        return t[id] || null
    }
    function hatSpot(id) {
        var t = {
            1: {ax: 0.298, ay: 0.108, lx: 0.012, ly: 0.005}
        }
        return t[id] || null
    }
    function axisFlag(id, key, fallback) {
        var s = axisSpot(id)
        if (!s || s[key] === undefined) {
            return fallback
        }
        return s[key]
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
        property bool showLine: true
        property bool showDot: true

        anchors.fill: parent
        z: 2

        Canvas {
            id: _line
            anchors.fill: parent
            visible: showLine
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = lit ? "#86EFAC" : "#A1A1AA"
                ctx.lineWidth = 1.15
                ctx.beginPath()
                ctx.moveTo(px(ax), py(ay))
                ctx.lineTo(px(lx) + 8, py(ly) + 10)
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
            visible: showDot
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
            showLine: visible ? _face.spotOn(identifier, "line", true) : true
            showDot: visible ? _face.spotOn(identifier, "dot", true) : true
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
            showLine: visible ? _face.axisFlag(identifier, "line", true) : true
            showDot: visible ? _face.axisFlag(identifier, "dot", true) : true
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
