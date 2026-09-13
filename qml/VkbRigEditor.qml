// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: _ed

    property var face: null
    property var nodes: []
    property string selectedId: ""
    property int selectedSpine: -1
    property string dragKind: ""
    property int dragSpine: -1
    property real dragOffX: 0
    property real dragOffY: 0
    property int tick: 0
    property bool seeded: false
    property bool interactive: false

    // Do NOT declare signal nodesChanged — property var nodes already has it.
    signal selectedChanged()

    function bump() {
        tick++
        selectedChanged()
        if (_lines)
            _lines.requestPaint()
    }

    onInteractiveChanged: {
        if (!interactive) {
            selectedId = ""
            selectedSpine = -1
            dragKind = ""
        }
        if (_lines)
            _lines.requestPaint()
    }

    function nodeAt(id) {
        var list = nodes || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                return list[i]
            }
        }
        return null
    }

    function nodeIndex(id) {
        var list = nodes || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                return i
            }
        }
        return -1
    }

    function destOf(kind, hwId) {
        tick
        if (!face) {
            return "—"
        }
        if (kind === "axis" || kind === "axis_stack") {
            return face.shortDest(face.labelAxis(hwId))
        }
        if (kind === "hat") {
            return face.shortDest(face.labelHat(hwId))
        }
        return face.shortDest(face.labelBtn(hwId))
    }

    function litOf(kind, hwId) {
        tick
        if (!face) {
            return false
        }
        if (kind === "axis" || kind === "axis_stack") {
            return Math.abs(face.hwAxis(hwId)) > 0.12
        }
        if (kind === "hat") {
            return face.hwHat(hwId) > 0.5
        }
        return face.hwButton(hwId) > 0.5
    }

    function chipXY(n) {
        return Qt.point(n.chipFx * width, n.chipFy * height)
    }

    function pinPt(n, item) {
        if (!item) {
            return chipXY(n)
        }
        var side = n.pin || "right"
        var x = side === "right" ? item.width : (side === "left" ? 0 : item.width * 0.5)
        var y = side === "top" ? 0 : item.height * 0.5
        return item.mapToItem(_ed, x, y)
    }

    function hotPt(n) {
        if (!face || !face.photoPt) {
            return Qt.point(0, 0)
        }
        return face.photoPt(n.nx, n.ny)
    }

    function toPhoto(mx, my) {
        if (!face || !face.toPhoto) {
            return Qt.point(0, 0)
        }
        return face.toPhoto(mx, my)
    }

    function ensureMidSpine(n) {
        if (n.spines && n.spines.length) {
            return
        }
        var item = _chips.itemAt(nodeIndex(n.id))
        var a = pinPt(n, item)
        var b = hotPt(n)
        n.spines = [{ fx: ((a.x + b.x) * 0.5) / Math.max(1, width), fy: ((a.y + b.y) * 0.5) / Math.max(1, height) }]
    }

    function hitTest(mx, my) {
        var list = nodes || []
        var i
        var n
        for (i = 0; i < list.length; i++) {
            n = list[i]
            var h = hotPt(n)
            if (Math.hypot(mx - h.x, my - h.y) < 10) {
                return { kind: "hot", id: n.id, spine: -1 }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            var spines = n.spines || []
            for (var s = 0; s < spines.length; s++) {
                var sx = spines[s].fx * width
                var sy = spines[s].fy * height
                if (Math.hypot(mx - sx, my - sy) < 9) {
                    return { kind: "spine", id: n.id, spine: s }
                }
            }
        }
        for (i = 0; i < list.length; i++) {
            var it = _chips.itemAt(i)
            if (!it) {
                continue
            }
            var p = it.mapFromItem(_ed, mx, my)
            if (p.x >= 0 && p.y >= 0 && p.x <= it.width && p.y <= it.height) {
                return { kind: "chip", id: list[i].id, spine: -1 }
            }
        }
        for (i = 0; i < list.length; i++) {
            if (_nearLeader(list[i], mx, my)) {
                return { kind: "line", id: list[i].id, spine: -1 }
            }
        }
        return { kind: "", id: "", spine: -1 }
    }

    function _nearLeader(n, mx, my) {
        var item = _chips.itemAt(nodeIndex(n.id))
        var pts = [pinPt(n, item)]
        var spines = n.spines || []
        for (var s = 0; s < spines.length; s++) {
            pts.push(Qt.point(spines[s].fx * width, spines[s].fy * height))
        }
        pts.push(hotPt(n))
        for (var i = 0; i < pts.length - 1; i++) {
            if (_distSeg(mx, my, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y) < 6) {
                return true
            }
        }
        return false
    }

    function _distSeg(px, py, x1, y1, x2, y2) {
        var dx = x2 - x1
        var dy = y2 - y1
        var len = dx * dx + dy * dy
        if (len < 1) {
            return Math.hypot(px - x1, py - y1)
        }
        var t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / len))
        return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy))
    }

    function addSpineAt(id, mx, my) {
        var n = nodeAt(id)
        if (!n) {
            return
        }
        if (!n.spines) {
            n.spines = []
        }
        n.spines.push({ fx: mx / Math.max(1, width), fy: my / Math.max(1, height) })
        selectedId = id
        selectedSpine = n.spines.length - 1
        selectedChanged()
        bump()
    }

    function deleteSelection() {
        var n = nodeAt(selectedId)
        if (!n) {
            return
        }
        if (selectedSpine >= 0 && n.spines && selectedSpine < n.spines.length) {
            n.spines.splice(selectedSpine, 1)
            selectedSpine = -1
            bump()
        }
    }

    Connections {
        target: face
        function onLiveStampChanged() { _ed.tick++ }
        function onDestTickChanged() { _ed.tick++ }
        function onWidthChanged() { _lines.requestPaint() }
        function onHeightChanged() { _lines.requestPaint() }
    }

    Repeater {
        id: _chips
        model: _ed.nodes
        delegate: Item {
            id: _wrap
            required property var modelData
            required property int index
            x: { _ed.tick; return modelData.chipFx * _ed.width }
            y: { _ed.tick; return modelData.chipFy * _ed.height }
            z: 3
            width: { _ed.tick; return _body.item ? Math.max(8, _body.item.implicitWidth) : 40 }
            height: { _ed.tick; return _body.item ? Math.max(8, _body.item.implicitHeight) : 20 }

            Loader {
                id: _body
                sourceComponent: {
                    var k = modelData.kind
                    if (k === "plus") return _plusComp
                    if (k === "pair" || k === "axis_stack") return _stackComp
                    return _tagComp
                }
                onLoaded: {
                    item.node = Qt.binding(function() { return modelData })
                }
            }
        }
    }

    Component {
        id: _tagComp
        Rectangle {
            property var node: ({ kind: "btn", hwId: 0 })
            property bool on: _ed.litOf(node.kind, node.hwId)
            implicitWidth: { _ed.tick; return _lab.implicitWidth + 10 }
            implicitHeight: { _ed.tick; return Math.max(18, (node.fontSize || 10) + 10) }
            radius: 4
            color: {
                _ed.tick
                return on && node.highlight ? (node.hlColor || "#14532D") : (node.color || "#18181B")
            }
            border.color: {
                _ed.tick
                if (_ed.selectedId === node.id) return "#FBBF24"
                return on && node.highlight ? (node.hlBorder || "#22C55E") : (node.border || "#3F3F46")
            }
            border.width: _ed.selectedId === node.id ? 2 : 1
            Text {
                id: _lab
                anchors.centerIn: parent
                color: {
                    _ed.tick
                    return on && node.highlight ? (node.hlText || "#BBF7D0") : (node.textColor || "#E4E4E7")
                }
                font.pixelSize: { _ed.tick; return node.fontSize || 10 }
                text: {
                    _ed.tick
                    if (node.label && node.label.length) return node.label
                    return (node.prefix || "") + node.hwId + " → " + _ed.destOf(node.kind, node.hwId)
                }
            }
        }
    }

    Component {
        id: _stackComp
        Item {
            property var node: ({ members: [] })
            implicitWidth: { _ed.tick; return Math.max(8, _stackCol.childrenRect.width) }
            implicitHeight: { _ed.tick; return Math.max(8, _stackCol.childrenRect.height) }
            width: implicitWidth
            height: implicitHeight
            Column {
                id: _stackCol
                spacing: 3
                Repeater {
                    model: { _ed.tick; return node.members || [] }
                    Rectangle {
                        required property var modelData
                        property bool on: _ed.litOf(node.kind === "axis_stack" ? "axis" : "btn", modelData.hwId)
                        implicitWidth: t.implicitWidth + 10
                        implicitHeight: Math.max(18, (node.fontSize || 10) + 10)
                        radius: 4
                        color: on && node.highlight ? (node.hlColor || "#14532D") : (node.color || "#18181B")
                        border.color: {
                            if (_ed.selectedId === node.id) return "#FBBF24"
                            return on && node.highlight ? (node.hlBorder || "#22C55E") : (node.border || "#3F3F46")
                        }
                        Text {
                            id: t
                            anchors.centerIn: parent
                            color: parent.on && node.highlight ? (node.hlText || "#BBF7D0") : (node.textColor || "#E4E4E7")
                            font.pixelSize: node.fontSize || 10
                            text: {
                                _ed.tick
                                return (node.kind === "axis_stack" ? "A" : "") + modelData.hwId + " → " + _ed.destOf(node.kind === "axis_stack" ? "axis" : "btn", modelData.hwId)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: _plusComp
        Item {
            id: _plusRoot
            property var node: ({ members: [] })
            implicitWidth: { _ed.tick; return Math.max(8, _plus.childrenRect.width) }
            implicitHeight: { _ed.tick; return Math.max(8, _plus.childrenRect.height) }
            width: implicitWidth
            height: implicitHeight
            function mem(role) {
                var m = node.members || []
                for (var i = 0; i < m.length; i++) {
                    if (m[i].role === role) return m[i].hwId
                }
                return 0
            }
            function bindMini(item, role) {
                item.node = Qt.binding(function() { return _plusRoot.node })
                item.hwId = Qt.binding(function() { return _plusRoot.mem(role) })
            }
            Grid {
                id: _plus
                columns: 3
                rows: 3
                spacing: 3
                Item { width: 8; height: 8 }
                Loader { sourceComponent: _mini; onLoaded: _plusRoot.bindMini(item, "up") }
                Item { width: 8; height: 8 }
                Loader { sourceComponent: _mini; onLoaded: _plusRoot.bindMini(item, "left") }
                Loader { sourceComponent: _mini; onLoaded: _plusRoot.bindMini(item, "center") }
                Loader { sourceComponent: _mini; onLoaded: _plusRoot.bindMini(item, "right") }
                Item { width: 8; height: 8 }
                Loader { sourceComponent: _mini; onLoaded: _plusRoot.bindMini(item, "down") }
                Item { width: 8; height: 8 }
            }
        }
    }

    Component {
        id: _mini
        Rectangle {
            property int hwId: 0
            property var node: ({})
            property bool on: _ed.litOf("btn", hwId)
            implicitWidth: { _ed.tick; return t.implicitWidth + 10 }
            implicitHeight: { _ed.tick; return Math.max(18, (node.fontSize || 10) + 10) }
            radius: 4
            color: {
                _ed.tick
                return on && node.highlight ? (node.hlColor || "#14532D") : (node.color || "#18181B")
            }
            border.color: {
                _ed.tick
                if (_ed.selectedId === node.id) return "#FBBF24"
                return on && node.highlight ? (node.hlBorder || "#22C55E") : (node.border || "#3F3F46")
            }
            Text {
                id: t
                anchors.centerIn: parent
                color: {
                    _ed.tick
                    return parent.on && node.highlight ? (node.hlText || "#BBF7D0") : (node.textColor || "#E4E4E7")
                }
                font.pixelSize: { _ed.tick; return node.fontSize || 10 }
                text: { _ed.tick; return hwId + " → " + _ed.destOf("btn", hwId) }
            }
        }
    }

    onWidthChanged: _lines.requestPaint()
    onHeightChanged: _lines.requestPaint()
    onTickChanged: _lines.requestPaint()
    onNodesChanged: {
        seeded = false
        _lines.requestPaint()
        _seedTimer.restart()
    }

    Timer {
        id: _seedTimer
        interval: 80
        repeat: false
        onTriggered: {
            var list = _ed.nodes || []
            for (var i = 0; i < list.length; i++) {
                _ed.ensureMidSpine(list[i])
            }
            _ed.seeded = true
            _ed.bump()
        }
    }

    Canvas {
        id: _lines
        anchors.fill: parent
        z: 2
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var list = _ed.nodes || []
            for (var i = 0; i < list.length; i++) {
                var n = list[i]
                var item = _chips.itemAt(i)
                var a = _ed.pinPt(n, item)
                var b = _ed.hotPt(n)
                ctx.strokeStyle = (_ed.interactive && _ed.selectedId === n.id) ? "#FBBF24" : "#A1A1AA"
                ctx.lineWidth = (_ed.interactive && _ed.selectedId === n.id) ? 1.6 : 1.1
                ctx.beginPath()
                ctx.moveTo(a.x, a.y)
                var spines = n.spines || []
                for (var s = 0; s < spines.length; s++) {
                    ctx.lineTo(spines[s].fx * width, spines[s].fy * height)
                }
                ctx.lineTo(b.x, b.y)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(b.x, b.y, 4.5, 0, 6.3)
                ctx.fillStyle = (_ed.interactive && _ed.selectedId === n.id) ? "#FBBF24" : "#F4F4F5"
                ctx.fill()
                if (_ed.interactive) {
                    for (s = 0; s < spines.length; s++) {
                        var sx = spines[s].fx * width
                        var sy = spines[s].fy * height
                        ctx.beginPath()
                        ctx.arc(sx, sy, 5, 0, 6.3)
                        ctx.fillStyle = (_ed.selectedId === n.id && _ed.selectedSpine === s) ? "#F59E0B" : "#94A3B8"
                        ctx.fill()
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 8
        enabled: _ed.interactive
        hoverEnabled: _ed.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        focus: true
        Keys.onDeletePressed: _ed.deleteSelection()
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Backspace) {
                _ed.deleteSelection()
            }
        }

        onPressed: (m) => {
            forceActiveFocus()
            var hit = _ed.hitTest(m.x, m.y)
            if (m.button === Qt.RightButton && hit.kind === "spine") {
                var n = _ed.nodeAt(hit.id)
                if (n && n.spines) {
                    n.spines.splice(hit.spine, 1)
                    _ed.selectedSpine = -1
                    _ed.bump()
                }
                return
            }
            if (hit.kind === "line") {
                _ed.addSpineAt(hit.id, m.x, m.y)
                return
            }
            _ed.selectedId = hit.id
            _ed.selectedSpine = hit.spine
            _ed.dragKind = hit.kind
            _ed.dragSpine = hit.spine
            _ed.selectedChanged()
            if (hit.kind === "chip") {
                var n2 = _ed.nodeAt(hit.id)
                if (n2) {
                    _ed.dragOffX = m.x - n2.chipFx * width
                    _ed.dragOffY = m.y - n2.chipFy * height
                }
            }
            _ed.bump()
        }
        onPositionChanged: (m) => {
            if (!pressed || !_ed.dragKind) {
                return
            }
            var n = _ed.nodeAt(_ed.selectedId)
            if (!n) {
                return
            }
            if (_ed.dragKind === "hot") {
                var p = _ed.toPhoto(m.x, m.y)
                n.nx = Math.max(0, Math.min(1, p.x))
                n.ny = Math.max(0, Math.min(1, p.y))
            } else if (_ed.dragKind === "chip") {
                n.chipFx = Math.max(0, Math.min(0.95, (m.x - _ed.dragOffX) / Math.max(1, width)))
                n.chipFy = Math.max(0, Math.min(0.95, (m.y - _ed.dragOffY) / Math.max(1, height)))
            } else if (_ed.dragKind === "spine" && n.spines && _ed.dragSpine >= 0) {
                n.spines[_ed.dragSpine].fx = Math.max(0, Math.min(1, m.x / Math.max(1, width)))
                n.spines[_ed.dragSpine].fy = Math.max(0, Math.min(1, m.y / Math.max(1, height)))
            }
            _ed.bump()
        }
        onReleased: {
            _ed.dragKind = ""
        }
        onDoubleClicked: (m) => {
            var hit = _ed.hitTest(m.x, m.y)
            if (hit.kind === "line" || hit.kind === "hot") {
                _ed.addSpineAt(hit.id || _ed.selectedId, m.x, m.y)
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 6
        z: 9
        visible: _ed.interactive
        color: "#A1A1AA"
        font.pixelSize: 10
        text: "Drag hotspot / chip / spine. Click a leader to add a spine. Del or right-click spine to remove."
    }
}
