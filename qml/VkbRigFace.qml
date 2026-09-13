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

    function photoPt(nx, ny) {
        return _img.mapToItem(_face, _ox + nx * _pw, _oy + ny * _ph)
    }

    function hwButton(id) { return host && host.hwButton ? host.hwButton(id) : 0 }
    function hwAxis(id) { return host && host.hwAxis ? host.hwAxis(id) : 0 }
    function hwHat(id) { return host && host.hwHat ? host.hwHat(id) : 0 }

    function shortDest(s) {
        var t = String(s || "—")
        t = t.replace(/vJoy Device /g, "")
        t = t.replace(/vJoy /g, "")
        t = t.replace(/vJ\d+\s*/g, "")
        t = t.replace(/^\d+\s+/, "")
        t = t.replace(/Xbox 360 Controller /g, "")
        t = t.replace(/Xbox /g, "")
        t = t.replace(/X360 \d+\s*/g, "")
        t = t.replace(/Right Trigger/g, "RT")
        t = t.replace(/Left Trigger/g, "LT")
        t = t.replace(/Right Stick /g, "RS ")
        t = t.replace(/Left Stick /g, "LS ")
        t = t.replace(/Button /g, "B")
        t = t.replace(/ \+ /g, "+")
        t = t.replace(/ +/g, " ")
        t = t.trim()
        return t.length ? t : "—"
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
        var y = side === "top" ? 0 : item.height * 0.5
        return item.mapToItem(_face, x, y)
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

        implicitWidth: _lab.implicitWidth + 10
        implicitHeight: 20
        radius: 4
        color: lit ? "#14532D" : "#18181B"
        border.color: lit ? "#22C55E" : "#3F3F46"
        Text {
            id: _lab
            anchors.centerIn: parent
            color: lit ? "#BBF7D0" : "#E4E4E7"
            font.pixelSize: 10
            text: prefix + hwId + " → " + _face.shortDest(_dest)
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
            spacing: 3
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            Item { width: 8; height: 8 }
            Tag { hwId: up }
            Item { width: 8; height: 8 }
            Tag { hwId: leftId }
            Tag { hwId: center }
            Tag { hwId: rightId }
            Item { width: 8; height: 8 }
            Tag { hwId: down }
            Item { width: 8; height: 8 }
        }
    }

    // Chip zones (not hotspots). Dots stay on qml/vkb_evo_r_face_map.md JPEG pixels.
    // L: H1, 11-15, 3, 6-10, 16-20, A1-A3 low by the shaft.
    // R: 4, 21/22, 1/2, 5.
    // B: 28, 27, 29, 25/26, A4, 23/24.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Item {
                Layout.preferredWidth: 300
                Layout.maximumWidth: 300
                Layout.fillHeight: true
                clip: true

                Column {
                    id: _left
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    width: 292

                    Tag { id: _h1; kind: "hat"; hwId: 1; prefix: "H"; anchors.horizontalCenter: parent.horizontalCenter }
                    HatPlus { id: _p1115; up: 11; down: 13; leftId: 14; rightId: 12; center: 15; anchors.horizontalCenter: parent.horizontalCenter }
                    Tag { id: _b3; hwId: 3; anchors.horizontalCenter: parent.horizontalCenter }
                    HatPlus { id: _p610; up: 6; down: 8; leftId: 9; rightId: 7; center: 10; anchors.horizontalCenter: parent.horizontalCenter }
                    HatPlus { id: _p1620; up: 16; down: 18; leftId: 19; rightId: 17; center: 20; anchors.horizontalCenter: parent.horizontalCenter }
                }

                Column {
                    id: _axes
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3
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
                Layout.preferredWidth: 160
                Layout.maximumWidth: 160
                Layout.fillHeight: true
                spacing: 6

                Tag { id: _b4; hwId: 4 }
                Column {
                    id: _p2122
                    spacing: 3
                    Tag { hwId: 21 }
                    Tag { hwId: 22 }
                }
                Column {
                    id: _p12
                    spacing: 3
                    Tag { hwId: 1 }
                    Tag { hwId: 2 }
                }
                Tag { id: _b5; hwId: 5 }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            Row {
                id: _bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Tag { id: _b28; hwId: 28; anchors.verticalCenter: parent.verticalCenter }
                Tag { id: _b27; hwId: 27; anchors.verticalCenter: parent.verticalCenter }
                Tag { id: _b29; hwId: 29; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    id: _p2526
                    spacing: 3
                    Tag { hwId: 25 }
                    Tag { hwId: 26 }
                }
                Tag { id: _a4; kind: "axis"; hwId: 4; prefix: "A"; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    id: _p2324
                    spacing: 3
                    Tag { hwId: 23 }
                    Tag { hwId: 24 }
                }
            }
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
                var a = _face.pin(item, side)
                var b = _face.photoPt(nx, ny)
                ctx.beginPath()
                ctx.moveTo(a.x, a.y)
                ctx.lineTo(b.x, b.y)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(b.x, b.y, 3.5, 0, 6.3)
                ctx.fillStyle = "#F4F4F5"
                ctx.fill()
            }

            // Pixels from qml/vkb_evo_r_face_map.md on JPEG 899x920.
            stroke(_h1, 0.345, 0.180, "right")
            stroke(_p1115, 0.425, 0.182, "right")
            stroke(_b3, 0.346, 0.254, "right")
            stroke(_p610, 0.423, 0.237, "right")
            stroke(_p1620, 0.400, 0.370, "right")
            stroke(_axes, 0.429, 0.575, "right")
            stroke(_b4, 0.613, 0.247, "left")
            stroke(_p2122, 0.656, 0.280, "left")
            stroke(_p12, 0.617, 0.301, "left")
            stroke(_b5, 0.605, 0.420, "left")
            stroke(_b28, 0.574, 0.711, "top")
            stroke(_b27, 0.621, 0.709, "top")
            stroke(_b29, 0.654, 0.700, "top")
            stroke(_p2526, 0.623, 0.798, "top")
            stroke(_a4, 0.665, 0.798, "top")
            stroke(_p2324, 0.739, 0.798, "top")
        }
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: _lines.requestPaint()
    }

    Connections {
        target: _face
        function onWidthChanged() { _lines.requestPaint() }
        function onHeightChanged() { _lines.requestPaint() }
        function onLiveStampChanged() { _lines.requestPaint() }
        function onDestTickChanged() { _lines.requestPaint() }
    }
}
