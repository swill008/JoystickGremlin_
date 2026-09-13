// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Layouts
import Gremlin.Style

Item {
    id: _face

    property var host: null
    property int liveStamp: 0
    property var buttons: null
    property var axes: null
    property var hats: null

    property var destBtn: ({})
    property var destAxis: ({})
    property var destHat: ({})
    property int destTick: 0

    readonly property real _pw: _img.paintedWidth
    readonly property real _ph: _img.paintedHeight
    readonly property real _ox: (_img.width - _pw) * 0.5
    readonly property real _oy: (_img.height - _ph) * 0.5

    function px(nx) { return _stage.x + _ox + nx * _pw }
    function py(ny) { return _stage.y + _oy + ny * _ph }

    function hwButton(id) { return host && host.hwButton ? host.hwButton(id) : 0 }
    function hwAxis(id) { return host && host.hwAxis ? host.hwAxis(id) : 0 }
    function hwHat(id) { return host && host.hwHat ? host.hwHat(id) : 0 }

    function shortDest(s) {
        var t = String(s || "—")
        t = t.replace(/vJoy Device /g, "vJ")
        t = t.replace(/vJoy /g, "vJ")
        t = t.replace(/Xbox 360 Controller /g, "X360 ")
        t = t.replace(/Xbox /g, "X360 ")
        t = t.replace(/Right Trigger/g, "RT")
        t = t.replace(/Left Trigger/g, "LT")
        t = t.replace(/Right Stick /g, "RS ")
        t = t.replace(/Left Stick /g, "LS ")
        t = t.replace(/Button /g, "B")
        t = t.replace(/ +/g, " ")
        return t
    }

    function labelBtn(id) {
        destTick
        var m = destBtn
        return (m && m[id]) ? m[id] : "—"
    }
    function labelAxis(id) {
        destTick
        var m = destAxis
        return (m && m[id]) ? m[id] : "—"
    }
    function labelHat(id) {
        destTick
        var m = destHat
        return (m && m[id]) ? m[id] : "—"
    }

    function pin(item, side) {
        if (!item) {
            return Qt.point(0, 0)
        }
        var x = side === "right" ? item.width : (side === "left" ? 0 : item.width * 0.5)
        var y = item.height * 0.5
        return item.mapToItem(_face, x, y)
    }

    function putBtn(id, label) {
        destBtn[id] = label
    }

    Repeater {
        model: _face.buttons
        Item {
            required property int identifier
            required property string vjoyLabel
            function bump() {
                var m = _face.destBtn
                m[identifier] = vjoyLabel
                _face.destBtn = m
                _face.destTick++
            }
            Component.onCompleted: bump()
            onVjoyLabelChanged: bump()
        }
    }
    Repeater {
        model: _face.axes
        Item {
            required property int identifier
            required property string vjoyLabel
            function bump() {
                var m = _face.destAxis
                m[identifier] = vjoyLabel
                _face.destAxis = m
                _face.destTick++
            }
            Component.onCompleted: bump()
            onVjoyLabelChanged: bump()
        }
    }
    Repeater {
        model: _face.hats
        Item {
            required property int identifier
            required property string vjoyLabel
            function bump() {
                var m = _face.destHat
                m[identifier] = vjoyLabel
                _face.destHat = m
                _face.destTick++
            }
            Component.onCompleted: bump()
            onVjoyLabelChanged: bump()
        }
    }

    component Tag: Rectangle {
        property int hwId: 0
        property string kind: "btn"
        property string prefix: ""

        readonly property string _dest: kind === "axis" ? _face.labelAxis(hwId)
                                      : kind === "hat" ? _face.labelHat(hwId)
                                      : _face.labelBtn(hwId)
        readonly property bool lit: {
            _face.liveStamp
            if (kind === "axis") {
                return Math.abs(_face.hwAxis(hwId)) > 0.12
            }
            if (kind === "hat") {
                return _face.hwHat(hwId) > 0.5
            }
            return _face.hwButton(hwId) > 0.5
        }

        implicitWidth: _lab.implicitWidth + 12
        implicitHeight: 22
        radius: 4
        color: lit ? "#14532D" : "#18181B"
        border.color: lit ? "#22C55E" : "#3F3F46"
        Text {
            id: _lab
            anchors.centerIn: parent
            color: lit ? "#BBF7D0" : "#E4E4E7"
            font.pixelSize: 11
            text: prefix + hwId + "  →  " + _face.shortDest(_dest)
        }
    }

    component HatPlus: Item {
        property int up: 0
        property int down: 0
        property int leftId: 0
        property int rightId: 0
        property int center: 0

        implicitWidth: _g.implicitWidth
        implicitHeight: _g.implicitHeight

        Grid {
            id: _g
            columns: 3
            rows: 3
            spacing: 4
            Item { width: 1; height: 1 }
            Tag { hwId: up }
            Item { width: 1; height: 1 }
            Tag { hwId: leftId }
            Tag { hwId: center }
            Tag { hwId: rightId }
            Item { width: 1; height: 1 }
            Tag { hwId: down }
            Item { width: 1; height: 1 }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Column {
                id: _left
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                spacing: 10

                Tag { id: _h1; kind: "hat"; hwId: 1; prefix: "H" }
                HatPlus { id: _p1115; up: 11; down: 13; leftId: 14; rightId: 12; center: 15 }
                HatPlus { id: _p610; up: 6; down: 8; leftId: 9; rightId: 7; center: 10 }
                Tag { id: _b3; hwId: 3 }
                HatPlus { id: _p1620; up: 16; down: 18; leftId: 19; rightId: 17; center: 20 }
                Column {
                    id: _axes
                    spacing: 4
                    Tag { kind: "axis"; hwId: 1; prefix: "A" }
                    Tag { kind: "axis"; hwId: 2; prefix: "A" }
                    Tag { kind: "axis"; hwId: 3; prefix: "A" }
                }
            }

            Item {
                id: _stage
                Layout.fillWidth: true
                Layout.fillHeight: true

                Image {
                    id: _img
                    anchors.fill: parent
                    source: Qt.resolvedUrl("images/vkb_gladiator_rig.jpg")
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    onStatusChanged: _lines.requestPaint()
                    onPaintedWidthChanged: _lines.requestPaint()
                    onPaintedHeightChanged: _lines.requestPaint()
                }
            }

            Column {
                id: _right
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                spacing: 8

                Tag { id: _b4; hwId: 4 }
                Column {
                    id: _p2122
                    spacing: 4
                    Tag { hwId: 21 }
                    Tag { hwId: 22 }
                }
                Column {
                    id: _p12
                    spacing: 4
                    Tag { hwId: 1 }
                    Tag { hwId: 2 }
                }
                Tag { id: _b5; hwId: 5 }
                Column {
                    id: _p2324
                    spacing: 4
                    Tag { hwId: 23 }
                    Tag { hwId: 24 }
                }
            }
        }

        Row {
            id: _bottom
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            spacing: 16
            layoutDirection: Qt.LeftToRight

            Column {
                id: _p2526
                spacing: 4
                Tag { hwId: 25 }
                Tag { hwId: 26 }
            }
            Item { width: 24; height: 1 }
            Tag { id: _b28; hwId: 28 }
            Tag { id: _b27; hwId: 27 }
            Tag { id: _b29; hwId: 29 }
            Item { width: 24; height: 1 }
            Tag { id: _a4; kind: "axis"; hwId: 4; prefix: "A" }
        }
    }

    Canvas {
        id: _lines
        anchors.fill: parent
        z: 1
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "#A1A1AA"
            ctx.lineWidth = 1.1

            function stroke(item, nx, ny, side) {
                if (!item) {
                    return
                }
                var p = _face.pin(item, side)
                ctx.beginPath()
                ctx.moveTo(p.x, p.y)
                ctx.lineTo(px(nx), py(ny))
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(px(nx), py(ny), 3.5, 0, 6.3)
                ctx.fillStyle = "#F4F4F5"
                ctx.fill()
            }

            stroke(_h1, 0.298, 0.108, "right")
            stroke(_p1115, 0.448, 0.135, "right")
            stroke(_p610, 0.392, 0.205, "right")
            stroke(_b3, 0.318, 0.198, "right")
            stroke(_p1620, 0.378, 0.365, "right")
            stroke(_axes, 0.430, 0.590, "right")
            stroke(_b4, 0.618, 0.168, "left")
            stroke(_p2122, 0.688, 0.246, "left")
            stroke(_p12, 0.655, 0.259, "left")
            stroke(_b5, 0.628, 0.430, "left")
            stroke(_p2324, 0.668, 0.795, "left")
            stroke(_p2526, 0.582, 0.782, "right")
            stroke(_b28, 0.558, 0.708, "top")
            stroke(_b27, 0.598, 0.698, "top")
            stroke(_b29, 0.638, 0.688, "top")
            stroke(_a4, 0.628, 0.778, "top")
        }
    }

    Connections {
        target: _face
        function onWidthChanged() { _lines.requestPaint() }
        function onHeightChanged() { _lines.requestPaint() }
        function onLiveStampChanged() { _lines.requestPaint() }
        function onDestTickChanged() { _lines.requestPaint() }
    }
}
