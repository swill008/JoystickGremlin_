// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import Gremlin.Style

Item {
    id: _face

    property var host: null
    property int liveStamp: 0

    readonly property real _pw: _img.paintedWidth
    readonly property real _ph: _img.paintedHeight
    readonly property real _ox: (_img.width - _pw) * 0.5
    readonly property real _oy: (_img.height - _ph) * 0.5

    function px(nx) { return _ox + nx * _pw }
    function py(ny) { return _oy + ny * _ph }

    function hwButton(id) { return host && host.hwButton ? host.hwButton(id) : 0 }
    function hwAxis(id) { return host && host.hwAxis ? host.hwAxis(id) : 0 }
    function hwHat(id) { return host && host.hwHat ? host.hwHat(id) : 0 }
    function destBtn(id) { return host && host.destBtn ? host.destBtn(id) : "—" }
    function destAxis(id) { return host && host.destAxis ? host.destAxis(id) : "—" }
    function destHat(id) { return host && host.destHat ? host.destHat(id) : "—" }

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

    // Physical marks on the photo only. Dest from pairing row for that id.
    Callout { ax: 0.30; ay: 0.20; lx: 0.01; ly: 0.04; hw: "HW Hat 1"; dest: (liveStamp, destHat(1)); lit: liveStamp, hwHat(1) > 0.5 }
    Callout { ax: 0.36; ay: 0.185; lx: 0.28; ly: 0.005; hw: "HW Hat 2"; dest: (liveStamp, destHat(2)); lit: liveStamp, hwHat(2) > 0.5 }
    Callout { ax: 0.335; ay: 0.235; lx: 0.01; ly: 0.11; hw: "HW Hat 3"; dest: (liveStamp, destHat(3)); lit: liveStamp, hwHat(3) > 0.5 }
    Callout { ax: 0.385; ay: 0.285; lx: 0.01; ly: 0.18; hw: "HW 2"; dest: (liveStamp, destBtn(2)); lit: liveStamp, hwButton(2) > 0.5 }
    Callout { ax: 0.30; ay: 0.355; lx: 0.01; ly: 0.25; hw: "HW 1"; dest: (liveStamp, destBtn(1)); lit: liveStamp, hwButton(1) > 0.5 }
    Callout { ax: 0.295; ay: 0.375; lx: 0.01; ly: 0.32; hw: "HW Axis T"; dest: (liveStamp, destAxis(3)); lit: liveStamp, Math.abs(hwAxis(3)) > 0.12 }
    Callout { ax: 0.43; ay: 0.40; lx: 0.01; ly: 0.39; hw: "HW Axis 4"; dest: (liveStamp, destAxis(4)); lit: liveStamp, Math.abs(hwAxis(4)) > 0.12 }
    Callout { ax: 0.43; ay: 0.40; lx: 0.01; ly: 0.46; hw: "HW Axis 5"; dest: (liveStamp, destAxis(5)); lit: liveStamp, Math.abs(hwAxis(5)) > 0.12 }
    Callout { ax: 0.455; ay: 0.405; lx: 0.01; ly: 0.53; hw: "HW 8"; dest: (liveStamp, destBtn(8)); lit: liveStamp, hwButton(8) > 0.5 }
    Callout { ax: 0.38; ay: 0.48; lx: 0.01; ly: 0.60; hw: "HW 9"; dest: (liveStamp, destBtn(9)); lit: liveStamp, hwButton(9) > 0.5 }
    Callout { ax: 0.40; ay: 0.52; lx: 0.01; ly: 0.67; hw: "HW 7"; dest: (liveStamp, destBtn(7)); lit: liveStamp, hwButton(7) > 0.5 }
    Callout { ax: 0.42; ay: 0.58; lx: 0.01; ly: 0.74; hw: "HW Axis X"; dest: (liveStamp, destAxis(1)); lit: liveStamp, Math.abs(hwAxis(1)) > 0.12 }
    Callout { ax: 0.42; ay: 0.60; lx: 0.01; ly: 0.81; hw: "HW Axis Y"; dest: (liveStamp, destAxis(2)); lit: liveStamp, Math.abs(hwAxis(2)) > 0.12 }

    Callout { ax: 0.62; ay: 0.22; lx: 0.78; ly: 0.04; hw: "HW Hat 1"; dest: (liveStamp, destHat(1)); lit: liveStamp, hwHat(1) > 0.5 }
    Callout { ax: 0.635; ay: 0.255; lx: 0.78; ly: 0.12; hw: "HW 3"; dest: (liveStamp, destBtn(3)); lit: liveStamp, hwButton(3) > 0.5 }
    Callout { ax: 0.64; ay: 0.30; lx: 0.78; ly: 0.20; hw: "HW 1"; dest: (liveStamp, destBtn(1)); lit: liveStamp, hwButton(1) > 0.5 }
    Callout { ax: 0.60; ay: 0.305; lx: 0.78; ly: 0.28; hw: "HW 2"; dest: (liveStamp, destBtn(2)); lit: liveStamp, hwButton(2) > 0.5 }
    Callout { ax: 0.655; ay: 0.325; lx: 0.78; ly: 0.36; hw: "HW Axis T"; dest: (liveStamp, destAxis(3)); lit: liveStamp, Math.abs(hwAxis(3)) > 0.12 }
    Callout { ax: 0.60; ay: 0.42; lx: 0.78; ly: 0.44; hw: "HW 4"; dest: (liveStamp, destBtn(4)); lit: liveStamp, hwButton(4) > 0.5 }
    Callout { ax: 0.58; ay: 0.38; lx: 0.78; ly: 0.52; hw: "HW 5"; dest: (liveStamp, destBtn(5)); lit: liveStamp, hwButton(5) > 0.5 }

    Callout { ax: 0.58; ay: 0.685; lx: 0.78; ly: 0.60; hw: "HW 10"; dest: (liveStamp, destBtn(10)); lit: liveStamp, hwButton(10) > 0.5 }
    Callout { ax: 0.62; ay: 0.695; lx: 0.78; ly: 0.67; hw: "HW 11"; dest: (liveStamp, destBtn(11)); lit: liveStamp, hwButton(11) > 0.5 }
    Callout { ax: 0.66; ay: 0.70; lx: 0.78; ly: 0.74; hw: "HW 12"; dest: (liveStamp, destBtn(12)); lit: liveStamp, hwButton(12) > 0.5 }
    Callout { ax: 0.58; ay: 0.78; lx: 0.01; ly: 0.88; hw: "HW Axis 6"; dest: (liveStamp, destAxis(6)); lit: liveStamp, Math.abs(hwAxis(6)) > 0.12 }
    Callout { ax: 0.64; ay: 0.80; lx: 0.42; ly: 0.94; hw: "HW Axis 7"; dest: (liveStamp, destAxis(7)); lit: liveStamp, Math.abs(hwAxis(7)) > 0.12 }
    Callout { ax: 0.70; ay: 0.78; lx: 0.78; ly: 0.82; hw: "HW Axis 8"; dest: (liveStamp, destAxis(8)); lit: liveStamp, Math.abs(hwAxis(8)) > 0.12 }
    Callout { ax: 0.58; ay: 0.78; lx: 0.01; ly: 0.94; hw: "HW 13"; dest: (liveStamp, destBtn(13)); lit: liveStamp, hwButton(13) > 0.5 }
}
