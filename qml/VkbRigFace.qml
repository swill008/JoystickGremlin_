// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import Gremlin.Style

Item {
    id: _face

    property string pairLabel: ""
    property var live: null
    property int buttonStamp: 0
    property int axisStamp: 0

    // painted image size
    readonly property real _pw: _img.paintedWidth
    readonly property real _ph: _img.paintedHeight
    readonly property real _ox: (_img.width - _pw) * 0.5
    readonly property real _oy: (_img.height - _ph) * 0.5

    function px(nx) { return _ox + nx * _pw }
    function py(ny) { return _oy + ny * _ph }

    function hwButton(id) {
        if (!live || buttonStamp < 0) return 0
        try { return live.buttonValue(id) } catch (e) { return 0 }
    }
    function hwAxis(id) {
        if (!live || axisStamp < 0) return 0
        try { return live.axisValue(id) } catch (e) { return 0 }
    }

    function destText(kind, id) {
        var dest = pairLabel && pairLabel.length ? pairLabel : "—"
        if (kind === "hat") return dest + " Hat " + id
        if (kind === "axis") return dest + " Axis " + id
        return dest + " Btn " + id
    }

    Image {
        id: _img
        anchors.fill: parent
        source: Qt.resolvedUrl("images/vkb_gladiator_rig.jpg")
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
    }

    component Callout: Item {
        property real ax: 0.5
        property real ay: 0.5
        property real lx: 0.05
        property real ly: 0.05
        property string hw: ""
        property string dest: ""
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
                ctx.lineTo(px(lx), py(ly) + 10)
                ctx.stroke()
            }
            Connections {
                target: _face
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
            x: px(lx) - (lx > 0.5 ? width - 8 : 0)
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

    // Left grip
    Callout { ax: 0.30; ay: 0.22; lx: 0.02; ly: 0.08; hw: "HW Hat 1"; dest: destText("hat", 1); lit: false }
    Callout { ax: 0.36; ay: 0.20; lx: 0.28; ly: 0.02; hw: "HW Hat 2"; dest: destText("hat", 2); lit: false }
    Callout { ax: 0.385; ay: 0.285; lx: 0.02; ly: 0.26; hw: "HW 2"; dest: destText("btn", 2); lit: hwButton(2) > 0.5 }
    Callout { ax: 0.30; ay: 0.355; lx: 0.02; ly: 0.34; hw: "HW 1"; dest: destText("btn", 1); lit: hwButton(1) > 0.5 }
    Callout { ax: 0.31; ay: 0.38; lx: 0.02; ly: 0.42; hw: "HW Axis T"; dest: destText("axis", 3); lit: Math.abs(hwAxis(3)) > 0.15 }
    Callout { ax: 0.43; ay: 0.40; lx: 0.02; ly: 0.50; hw: "HW Axis 4/5"; dest: destText("axis", 4); lit: Math.abs(hwAxis(4)) > 0.15 || Math.abs(hwAxis(5)) > 0.15 }
    Callout { ax: 0.455; ay: 0.405; lx: 0.02; ly: 0.58; hw: "HW 8 click"; dest: destText("btn", 8); lit: hwButton(8) > 0.5 }
    Callout { ax: 0.38; ay: 0.48; lx: 0.02; ly: 0.66; hw: "HW 9"; dest: destText("btn", 9); lit: hwButton(9) > 0.5 }
    Callout { ax: 0.42; ay: 0.58; lx: 0.02; ly: 0.74; hw: "HW Axis X/Y"; dest: destText("axis", 1); lit: Math.abs(hwAxis(1)) > 0.15 || Math.abs(hwAxis(2)) > 0.15 }

    // Right grip
    Callout { ax: 0.62; ay: 0.22; lx: 0.78; ly: 0.10; hw: "HW Hat 1"; dest: destText("hat", 1); lit: false }
    Callout { ax: 0.64; ay: 0.30; lx: 0.78; ly: 0.22; hw: "HW 1"; dest: destText("btn", 1); lit: hwButton(1) > 0.5 }
    Callout { ax: 0.60; ay: 0.305; lx: 0.78; ly: 0.32; hw: "HW 2"; dest: destText("btn", 2); lit: hwButton(2) > 0.5 }
    Callout { ax: 0.60; ay: 0.42; lx: 0.78; ly: 0.42; hw: "HW 4"; dest: destText("btn", 4); lit: hwButton(4) > 0.5 }

    // Base
    Callout { ax: 0.62; ay: 0.70; lx: 0.78; ly: 0.62; hw: "HW 10-12"; dest: destText("btn", 10); lit: hwButton(10) > 0.5 || hwButton(11) > 0.5 || hwButton(12) > 0.5 }
    Callout { ax: 0.58; ay: 0.78; lx: 0.02; ly: 0.84; hw: "HW Axis 6"; dest: destText("axis", 6); lit: Math.abs(hwAxis(6)) > 0.15 }
    Callout { ax: 0.64; ay: 0.80; lx: 0.50; ly: 0.94; hw: "HW Axis 7"; dest: destText("axis", 7); lit: Math.abs(hwAxis(7)) > 0.15 }
    Callout { ax: 0.70; ay: 0.78; lx: 0.78; ly: 0.84; hw: "HW Axis 8"; dest: destText("axis", 8); lit: Math.abs(hwAxis(8)) > 0.15 }
}
