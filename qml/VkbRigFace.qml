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

    // EVO R (right grip) + shared ids used by this device.
    function btnSpot(id) {
        var t = {
            1: {ax: 0.64, ay: 0.30, lx: 0.78, ly: 0.20},
            2: {ax: 0.60, ay: 0.305, lx: 0.78, ly: 0.28},
            3: {ax: 0.635, ay: 0.255, lx: 0.78, ly: 0.12},
            4: {ax: 0.60, ay: 0.42, lx: 0.78, ly: 0.44},
            5: {ax: 0.58, ay: 0.38, lx: 0.78, ly: 0.52},
            7: {ax: 0.40, ay: 0.52, lx: 0.01, ly: 0.67},
            8: {ax: 0.455, ay: 0.405, lx: 0.01, ly: 0.53},
            9: {ax: 0.38, ay: 0.48, lx: 0.01, ly: 0.60},
            10: {ax: 0.58, ay: 0.685, lx: 0.78, ly: 0.60},
            11: {ax: 0.62, ay: 0.695, lx: 0.78, ly: 0.67},
            12: {ax: 0.66, ay: 0.70, lx: 0.78, ly: 0.74},
            13: {ax: 0.58, ay: 0.78, lx: 0.01, ly: 0.94}
        }
        return t[id] || null
    }
    function hasBtn(id) { return btnSpot(id) !== null }
    function hasAxis(id) { return axisSpot(id) !== null }
    function hasHat(id) { return hatSpot(id) !== null }
    function axisSpot(id) {
        var t = {
            1: {ax: 0.42, ay: 0.58, lx: 0.01, ly: 0.74},
            2: {ax: 0.42, ay: 0.60, lx: 0.01, ly: 0.81},
            3: {ax: 0.655, ay: 0.325, lx: 0.78, ly: 0.36},
            4: {ax: 0.43, ay: 0.40, lx: 0.01, ly: 0.39},
            5: {ax: 0.43, ay: 0.40, lx: 0.01, ly: 0.46},
            6: {ax: 0.58, ay: 0.78, lx: 0.01, ly: 0.88},
            7: {ax: 0.64, ay: 0.80, lx: 0.42, ly: 0.94},
            8: {ax: 0.70, ay: 0.78, lx: 0.78, ly: 0.82}
        }
        return t[id] || null
    }
    function hatSpot(id) {
        var t = {
            1: {ax: 0.62, ay: 0.22, lx: 0.78, ly: 0.04},
            2: {ax: 0.36, ay: 0.185, lx: 0.28, ly: 0.005},
            3: {ax: 0.335, ay: 0.235, lx: 0.01, ly: 0.11}
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
