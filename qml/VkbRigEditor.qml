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
    property var selectedIds: []
    property bool banding: false
    property bool bandAdd: false
    property real bandX0: 0
    property real bandY0: 0
    property real bandX1: 0
    property real bandY1: 0
    property bool gridOn: true
    property bool snapOn: true
    property int gridSize: 8

    // Do NOT declare signal nodesChanged — property var nodes already has it.
    signal selectedChanged()

    function repaint() {
        tick++
        if (_lines)
            _lines.requestPaint()
    }

    function bump() {
        repaint()
        selectedChanged()
    }

    function applyField(key, val) {
        var ids = (selectedIds && selectedIds.length) ? selectedIds : (selectedId ? [selectedId] : [])
        for (var i = 0; i < ids.length; i++) {
            var n = nodeAt(ids[i])
            if (n)
                n[key] = val
        }
        bump()
    }

    function snapPx(v) {
        var g = gridSize
        if (!snapOn || g < 2)
            return v
        return Math.round(v / g) * g
    }

    function snapPos(x, y, altOff) {
        if (altOff || !snapOn)
            return Qt.point(x, y)
        return Qt.point(snapPx(x), snapPx(y))
    }

    onInteractiveChanged: {
        if (!interactive) {
            selectedId = ""
            selectedIds = []
            selectedSpine = -1
            dragKind = ""
            banding = false
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

    function pinPt(n, item, side) {
        if (!item) {
            return chipXY(n)
        }
        var pin = side || (n ? n.pin : "right") || "right"
        var x = pin === "right" ? item.width : (pin === "left" ? 0 : item.width * 0.5)
        var y = pin === "top" ? 0 : (pin === "bottom" ? item.height : item.height * 0.5)
        return item.mapToItem(_ed, x, y)
    }

    function hotPt(n) {
        if (!n || !face || !face.photoPt) {
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

    function fromEnd(n) {
        if (n && n.from && n.from.type)
            return n.from
        return { type: "chip", id: n ? n.id : "", pin: n && n.pin ? n.pin : "right" }
    }

    function toEnd(n) {
        if (n && n.to && n.to.type)
            return n.to
        return { type: "hot", id: n ? n.id : "" }
    }

    function endPt(end) {
        if (!end)
            return Qt.point(0, 0)
        if (end.type === "free")
            return Qt.point((end.fx || 0) * width, (end.fy || 0) * height)
        if (end.type === "chip") {
            var cn = nodeAt(end.id)
            var it = _chips.itemAt(nodeIndex(end.id))
            return pinPt(cn, it, end.pin)
        }
        if (end.type === "hot") {
            return hotPt(nodeAt(end.id))
        }
        return Qt.point(0, 0)
    }

    function pathPts(n) {
        var pts = [endPt(fromEnd(n))]
        var spines = n.spines || []
        for (var s = 0; s < spines.length; s++) {
            pts.push(Qt.point(spines[s].fx * width, spines[s].fy * height))
        }
        pts.push(endPt(toEnd(n)))
        return pts
    }

    function chipH(n) {
        return Math.max(n && n.chipSize ? n.chipSize : 18, ((n && n.fontSize) || 10) + 8)
    }

    function chipR(n, h) {
        return ((n && n.chipShape) || "round") === "square" ? 0 : Math.max(2, h * 0.5)
    }

    function chipIsHollow(n) {
        return ((n && n.chipFill) || "filled") === "hollow"
    }

    function hotSz(n) {
        return (n && n.hotSize) ? n.hotSize : 9
    }

    function drawMark(ctx, x, y, size, shape, fill, color) {
        var r = Math.max(2, size * 0.5)
        ctx.beginPath()
        if (shape === "square")
            ctx.rect(x - r, y - r, r * 2, r * 2)
        else
            ctx.arc(x, y, r, 0, 6.2832)
        if (fill === "hollow") {
            ctx.strokeStyle = color
            ctx.lineWidth = 2
            ctx.stroke()
        } else {
            ctx.fillStyle = color
            ctx.fill()
        }
    }

    function nearestPin(item, mx, my) {
        if (!item)
            return "right"
        var p = item.mapFromItem(_ed, mx, my)
        var dl = Math.abs(p.x)
        var dr = Math.abs(item.width - p.x)
        var dt = Math.abs(p.y)
        var db = Math.abs(item.height - p.y)
        var m = Math.min(dl, dr, dt, db)
        if (m === dt) return "top"
        if (m === db) return "bottom"
        if (m === dl) return "left"
        return "right"
    }

    function attachNear(x, y) {
        var list = nodes || []
        var best = { type: "free", fx: x / Math.max(1, width), fy: y / Math.max(1, height) }
        var bestD = 16
        var i
        for (i = 0; i < list.length; i++) {
            var h = hotPt(list[i])
            var hd = Math.hypot(x - h.x, y - h.y)
            var lim = hotSz(list[i]) * 0.5 + 10
            if (hd < lim && hd < bestD) {
                bestD = hd
                best = { type: "hot", id: list[i].id }
            }
        }
        for (i = 0; i < list.length; i++) {
            var it = _chips.itemAt(i)
            if (!it)
                continue
            var p = it.mapFromItem(_ed, x, y)
            var dx = p.x < 0 ? -p.x : (p.x > it.width ? p.x - it.width : 0)
            var dy = p.y < 0 ? -p.y : (p.y > it.height ? p.y - it.height : 0)
            var cd = Math.hypot(dx, dy)
            if (cd < 14 && cd < bestD) {
                bestD = cd
                best = { type: "chip", id: list[i].id, pin: nearestPin(it, x, y) }
            }
        }
        return best
    }

    function detachEnd(which) {
        var n = nodeAt(selectedId)
        if (!n) return
        var p = endPt(which === "to" ? toEnd(n) : fromEnd(n))
        var free = { type: "free", fx: p.x / Math.max(1, width), fy: p.y / Math.max(1, height) }
        if (which === "to") n.to = free
        else n.from = free
        bump()
    }

    function attachEndToSelf(which) {
        var n = nodeAt(selectedId)
        if (!n) return
        if (which === "to") n.to = { type: "hot", id: n.id }
        else n.from = { type: "chip", id: n.id, pin: n.pin || "right" }
        bump()
    }

    function _clampPt(pts, i) {
        if (i < 0) return pts[0]
        if (i >= pts.length) return pts[pts.length - 1]
        return pts[i]
    }

    function _bezierCtrl(pts, i) {
        var p0 = _clampPt(pts, i - 1)
        var p1 = pts[i]
        var p2 = pts[i + 1]
        var p3 = _clampPt(pts, i + 2)
        return {
            c1x: p1.x + (p2.x - p0.x) / 6.0,
            c1y: p1.y + (p2.y - p0.y) / 6.0,
            c2x: p2.x - (p3.x - p1.x) / 6.0,
            c2y: p2.y - (p3.y - p1.y) / 6.0,
            x: p2.x,
            y: p2.y
        }
    }

    function strokeLeader(ctx, n, pts) {
        if (!pts || pts.length < 2) return
        ctx.beginPath()
        ctx.moveTo(pts[0].x, pts[0].y)
        if (n.curve === false || pts.length === 2) {
            for (var i = 1; i < pts.length; i++) {
                ctx.lineTo(pts[i].x, pts[i].y)
            }
        } else {
            for (var j = 0; j < pts.length - 1; j++) {
                var c = _bezierCtrl(pts, j)
                ctx.bezierCurveTo(c.c1x, c.c1y, c.c2x, c.c2y, c.x, c.y)
            }
        }
        ctx.stroke()
    }

    function ensureMidSpine(n) {
        if (n.spines && n.spines.length) {
            return
        }
        var a = endPt(fromEnd(n))
        var b = endPt(toEnd(n))
        n.spines = [{ fx: ((a.x + b.x) * 0.5) / Math.max(1, width), fy: ((a.y + b.y) * 0.5) / Math.max(1, height) }]
    }

    function addCurveSpine(n) {
        if (!n) return
        n.curve = true
        var a = endPt(fromEnd(n))
        var b = endPt(toEnd(n))
        var spines = n.spines || []
        if (spines.length) {
            a = Qt.point(spines[spines.length - 1].fx * width, spines[spines.length - 1].fy * height)
        }
        var dx = b.x - a.x
        var dy = b.y - a.y
        var len = Math.hypot(dx, dy) || 1
        var ox = -dy / len * 36
        var oy = dx / len * 36
        var mx = (a.x + b.x) * 0.5
        var my = (a.y + b.y) * 0.5
        var cx = width * 0.5
        var cy = height * 0.5
        var dPos = Math.hypot(mx + ox - cx, my + oy - cy)
        var dNeg = Math.hypot(mx - ox - cx, my - oy - cy)
        if (dPos > dNeg) {
            ox = -ox
            oy = -oy
        }
        if (!n.spines) n.spines = []
        n.spines.push({ fx: (mx + ox) / Math.max(1, width), fy: (my + oy) / Math.max(1, height) })
        selectedId = n.id
        selectedSpine = n.spines.length - 1
        selectedChanged()
        bump()
    }

    function hitTest(mx, my) {
        var list = nodes || []
        var i
        var n
        for (i = 0; i < list.length; i++) {
            n = list[i]
            var fp = endPt(fromEnd(n))
            if (Math.hypot(mx - fp.x, my - fp.y) < 9) {
                return { kind: "from", id: n.id, spine: -1 }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            var te = toEnd(n)
            var tp = endPt(te)
            if (te.type !== "hot" && Math.hypot(mx - tp.x, my - tp.y) < 9) {
                return { kind: "to", id: n.id, spine: -1 }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            var h = hotPt(n)
            if (Math.hypot(mx - h.x, my - h.y) < (hotSz(n) * 0.5 + 5)) {
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
        var pts = pathPts(n)
        if (n.curve === false || pts.length < 3) {
            for (var i = 0; i < pts.length - 1; i++) {
                if (_distSeg(mx, my, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y) < 6) {
                    return true
                }
            }
            return false
        }
        var steps = 8
        for (var j = 0; j < pts.length - 1; j++) {
            var c = _bezierCtrl(pts, j)
            var p1x = pts[j].x
            var p1y = pts[j].y
            var prevx = p1x
            var prevy = p1y
            for (var s = 1; s <= steps; s++) {
                var tt = s / steps
                var u = 1 - tt
                var x = u*u*u*p1x + 3*u*u*tt*c.c1x + 3*u*tt*tt*c.c2x + tt*tt*tt*c.x
                var y = u*u*u*p1y + 3*u*u*tt*c.c1y + 3*u*tt*tt*c.c2y + tt*tt*tt*c.y
                if (_distSeg(mx, my, prevx, prevy, x, y) < 6) {
                    return true
                }
                prevx = x
                prevy = y
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
        var pts = pathPts(n)
        var best = 0
        var bestD = 1e9
        for (var i = 0; i < pts.length - 1; i++) {
            var d = _distSeg(mx, my, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y)
            if (d < bestD) {
                bestD = d
                best = i
            }
        }
        var spn = snapPos(mx, my, false)
        n.spines.splice(best, 0, { fx: spn.x / Math.max(1, width), fy: spn.y / Math.max(1, height) })
        selectedId = id
        selectedSpine = best
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

    function isSelected(id) {
        if (!id)
            return false
        if (selectedId === id)
            return true
        var s = selectedIds || []
        for (var i = 0; i < s.length; i++) {
            if (s[i] === id)
                return true
        }
        return false
    }

    function setSelection(ids) {
        selectedIds = ids || []
        selectedId = selectedIds.length ? selectedIds[selectedIds.length - 1] : ""
        selectedSpine = -1
        selectedChanged()
    }

    function toggleSelected(id) {
        var s = (selectedIds || []).slice()
        var at = s.indexOf(id)
        if (at >= 0)
            s.splice(at, 1)
        else
            s.push(id)
        setSelection(s)
    }

    function isGroup(n) {
        if (!n)
            return false
        var k = n.kind
        return k === "plus" || k === "pair" || k === "axis_stack" || k === "stack"
    }

    function canGroup() {
        return (selectedIds || []).length >= 2
    }

    function canUngroup() {
        return isGroup(nodeAt(selectedId)) && (selectedIds || []).length <= 1
    }

    function _uid(prefix) {
        return prefix + "_" + Date.now().toString(36) + Math.floor(Math.random() * 1000)
    }

    function _styleOf(n) {
        return {
            color: n.color || "#18181B",
            border: n.border || "#3F3F46",
            textColor: n.textColor || "#E4E4E7",
            highlight: n.highlight !== false,
            hlColor: n.hlColor || "#14532D",
            hlBorder: n.hlBorder || "#22C55E",
            hlText: n.hlText || "#BBF7D0",
            fontSize: n.fontSize || 10,
            pin: n.pin || "right",
            curve: n.curve !== false,
            chipSize: n.chipSize || 18,
            chipShape: n.chipShape || "round",
            chipFill: n.chipFill || "filled",
            hotSize: n.hotSize || 9,
            hotShape: n.hotShape || "round",
            hotFill: n.hotFill || "filled"
        }
    }

    function _partsFrom(n) {
        var out = []
        if (!n)
            return out
        if (isGroup(n)) {
            var mem = n.members || []
            var leaf = n.kind === "axis_stack" ? "axis" : "btn"
            for (var i = 0; i < mem.length; i++)
                out.push({ hwId: mem[i].hwId, kind: leaf, role: mem[i].role || "", src: n })
        } else {
            out.push({ hwId: n.hwId, kind: n.kind || "btn", role: "", src: n })
        }
        return out
    }

    function _plusMembers(parts) {
        var leftover = parts.slice()
        function take(score) {
            var best = 0
            var bestS = 1e9
            for (var i = 0; i < leftover.length; i++) {
                var s = score(leftover[i].src)
                if (s < bestS) {
                    bestS = s
                    best = i
                }
            }
            return leftover.splice(best, 1)[0]
        }
        var cx = 0
        var cy = 0
        var i
        for (i = 0; i < parts.length; i++) {
            cx += parts[i].src.chipFx
            cy += parts[i].src.chipFy
        }
        cx /= Math.max(1, parts.length)
        cy /= Math.max(1, parts.length)
        var center = take(function(n) { return Math.hypot((n.chipFx || 0) - cx, (n.chipFy || 0) - cy) })
        var up = take(function(n) { return n.chipFy || 0 })
        var down = take(function(n) { return -(n.chipFy || 0) })
        var left = take(function(n) { return n.chipFx || 0 })
        var right = take(function(n) { return -(n.chipFx || 0) })
        return [
            { hwId: up.hwId, role: "up" },
            { hwId: down.hwId, role: "down" },
            { hwId: left.hwId, role: "left" },
            { hwId: right.hwId, role: "right" },
            { hwId: center.hwId, role: "center" }
        ]
    }

    function groupSelection() {
        var ids = selectedIds || []
        if (ids.length < 2)
            return
        var parts = []
        var i
        var n
        for (i = 0; i < ids.length; i++) {
            var chunk = _partsFrom(nodeAt(ids[i]))
            for (var p = 0; p < chunk.length; p++)
                parts.push(chunk[p])
        }
        if (parts.length < 2)
            return
        var axisN = 0
        for (i = 0; i < parts.length; i++) {
            if (parts[i].kind === "axis")
                axisN++
        }
        var kind = "stack"
        if (axisN === parts.length)
            kind = "axis_stack"
        else if (parts.length === 5 && axisN === 0)
            kind = "plus"
        var members
        if (kind === "plus") {
            members = _plusMembers(parts)
        } else {
            parts.sort(function(a, b) {
                var dy = (a.src.chipFy || 0) - (b.src.chipFy || 0)
                return dy !== 0 ? dy : ((a.src.chipFx || 0) - (b.src.chipFx || 0))
            })
            members = []
            for (i = 0; i < parts.length; i++)
                members.push({ hwId: parts[i].hwId, role: parts[i].role || ("m" + i) })
        }
        var first = nodeAt(ids[0])
        var st = _styleOf(first)
        var fx = 0
        var fy = 0
        var nx = 0
        var ny = 0
        for (i = 0; i < ids.length; i++) {
            n = nodeAt(ids[i])
            fx += n.chipFx
            fy += n.chipFy
            nx += n.nx
            ny += n.ny
        }
        var c = ids.length
        var g = {
            id: _uid("g"), kind: kind, members: members,
            nx: nx / c, ny: ny / c, chipFx: fx / c, chipFy: fy / c,
            pin: st.pin, spines: [], curve: st.curve,
            color: st.color, border: st.border, textColor: st.textColor,
            highlight: st.highlight, hlColor: st.hlColor, hlBorder: st.hlBorder,
            hlText: st.hlText, fontSize: st.fontSize, label: "", chipSize: st.chipSize, chipShape: st.chipShape, chipFill: st.chipFill, hotSize: st.hotSize, hotShape: st.hotShape, hotFill: st.hotFill
        }
        var drop = {}
        for (i = 0; i < ids.length; i++)
            drop[ids[i]] = true
        var list = nodes || []
        for (i = list.length - 1; i >= 0; i--) {
            if (drop[list[i].id])
                list.splice(i, 1)
        }
        list.push(g)
        setSelection([g.id])
        bump()
    }

    function ungroupSelection() {
        var n = nodeAt(selectedId)
        if (!isGroup(n))
            return
        var mem = n.members || []
        if (!mem.length)
            return
        var st = _styleOf(n)
        var leafKind = n.kind === "axis_stack" ? "axis" : "btn"
        var prefix = n.kind === "axis_stack" ? "A" : ""
        var created = []
        var i
        var dx
        var dy
        var role
        for (i = 0; i < mem.length; i++) {
            role = mem[i].role || ""
            dx = 0
            dy = (i - (mem.length - 1) * 0.5) * 0.028
            if (n.kind === "plus") {
                if (role === "up") { dx = 0; dy = -0.045 }
                else if (role === "down") { dx = 0; dy = 0.045 }
                else if (role === "left") { dx = -0.07; dy = 0 }
                else if (role === "right") { dx = 0.07; dy = 0 }
                else { dx = 0; dy = 0 }
            }
            created.push({
                id: _uid("b"), kind: leafKind, hwId: mem[i].hwId, prefix: prefix, label: "",
                nx: n.nx, ny: n.ny,
                chipFx: Math.max(0.02, Math.min(0.9, n.chipFx + dx)),
                chipFy: Math.max(0.02, Math.min(0.9, n.chipFy + dy)),
                pin: st.pin, spines: [], curve: st.curve,
                color: st.color, border: st.border, textColor: st.textColor,
                highlight: st.highlight, hlColor: st.hlColor, hlBorder: st.hlBorder,
                hlText: st.hlText, fontSize: st.fontSize, chipSize: st.chipSize, chipShape: st.chipShape, chipFill: st.chipFill, hotSize: st.hotSize, hotShape: st.hotShape, hotFill: st.hotFill
            })
        }
        var list = nodes || []
        var idx = nodeIndex(n.id)
        if (idx < 0)
            return
        list.splice(idx, 1)
        for (i = 0; i < created.length; i++)
            list.splice(idx + i, 0, created[i])
        var ids = []
        for (i = 0; i < created.length; i++)
            ids.push(created[i].id)
        setSelection(ids)
        bump()
    }

    function setGroupKind(kind) {
        var n = nodeAt(selectedId)
        if (!isGroup(n) || !kind)
            return
        n.kind = kind
        var mem = n.members || []
        if (kind === "plus" && mem.length === 5) {
            var roles = ["up", "down", "left", "right", "center"]
            for (var i = 0; i < 5; i++)
                mem[i].role = roles[i]
        }
        bump()
    }

    function selectBand(add) {
        var x0 = Math.min(bandX0, bandX1)
        var y0 = Math.min(bandY0, bandY1)
        var x1 = Math.max(bandX0, bandX1)
        var y1 = Math.max(bandY0, bandY1)
        var ids = add ? (selectedIds || []).slice() : []
        var list = nodes || []
        for (var i = 0; i < list.length; i++) {
            var it = _chips.itemAt(i)
            if (!it)
                continue
            var cx = it.x + it.width * 0.5
            var cy = it.y + it.height * 0.5
            if (cx >= x0 && cx <= x1 && cy >= y0 && cy <= y1) {
                if (ids.indexOf(list[i].id) < 0)
                    ids.push(list[i].id)
            }
        }
        setSelection(ids)
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
        model: { _ed.tick; return (_ed.nodes || []).length }
        delegate: Item {
            id: _wrap
            required property int index
            readonly property var node: {
                _ed.tick
                var list = _ed.nodes || []
                return (index >= 0 && index < list.length) ? list[index] : null
            }
            visible: node !== null
            x: { _ed.tick; return node ? node.chipFx * _ed.width : 0 }
            y: { _ed.tick; return node ? node.chipFy * _ed.height : 0 }
            z: 3
            width: { _ed.tick; return _body.item ? Math.max(8, _body.item.implicitWidth) : 40 }
            height: { _ed.tick; return _body.item ? Math.max(8, _body.item.implicitHeight) : 20 }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                z: -1
                radius: 6
                color: "transparent"
                border.width: 2
                border.color: {
                    _ed.tick
                    return (_wrap.node && _ed.isSelected(_wrap.node.id)) ? "#FBBF24" : "transparent"
                }
            }

            Loader {
                id: _body
                sourceComponent: {
                    _ed.tick
                    var n = _wrap.node
                    if (!n) return _tagComp
                    var k = n.kind
                    if (k === "plus") return _plusComp
                    if (k === "pair" || k === "axis_stack" || k === "stack") return _stackComp
                    return _tagComp
                }
                onLoaded: {
                    item.node = Qt.binding(function() { return _wrap.node })
                }
            }
        }
    }

    Component {
        id: _tagComp
        Rectangle {
            property var node: ({ kind: "btn", hwId: 0 })
            property bool on: _ed.litOf(node.kind, node.hwId)
            implicitWidth: { _ed.tick; return _lab.implicitWidth + Math.max(10, (node.chipSize || 18) * 0.55) }
            implicitHeight: { _ed.tick; return _ed.chipH(node) }
            radius: { _ed.tick; return _ed.chipR(node, height || _ed.chipH(node)) }
            color: {
                _ed.tick
                if (_ed.chipIsHollow(node)) return "transparent"
                return on && node.highlight ? (node.hlColor || "#14532D") : (node.color || "#18181B")
            }
            border.color: {
                _ed.tick
                if (_ed.isSelected(node.id)) return "#FBBF24"
                return on && node.highlight ? (node.hlBorder || "#22C55E") : (node.border || "#3F3F46")
            }
            border.width: { _ed.tick; return (_ed.isSelected(node.id) || _ed.chipIsHollow(node)) ? 2 : 1 }
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
            implicitWidth: { _ed.tick; return t.implicitWidth + Math.max(10, (node.chipSize || 18) * 0.55) }
            implicitHeight: { _ed.tick; return _ed.chipH(node) }
            radius: { _ed.tick; return _ed.chipR(node, height || _ed.chipH(node)) }
            color: {
                _ed.tick
                if (_ed.chipIsHollow(node)) return "transparent"
                return on && node.highlight ? (node.hlColor || "#14532D") : (node.color || "#18181B")
            }
            border.color: {
                _ed.tick
                if (_ed.isSelected(node.id)) return "#FBBF24"
                return on && node.highlight ? (node.hlBorder || "#22C55E") : (node.border || "#3F3F46")
            }
            border.width: { _ed.tick; return (_ed.isSelected(node.id) || _ed.chipIsHollow(node)) ? 2 : 1 }
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

    onWidthChanged: { _lines.requestPaint(); if (_grid) _grid.requestPaint() }
    onHeightChanged: { _lines.requestPaint(); if (_grid) _grid.requestPaint() }
    onTickChanged: _lines.requestPaint()
    onGridOnChanged: if (_grid) _grid.requestPaint()
    onGridSizeChanged: if (_grid) _grid.requestPaint()
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
        id: _grid
        anchors.fill: parent
        z: 1
        visible: _ed.interactive && _ed.gridOn
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var g = Math.max(2, _ed.gridSize)
            var w = width
            var h = height
            var x
            var y
            var major = g * 4
            ctx.lineWidth = 1
            ctx.strokeStyle = "#14FFFFFF"
            ctx.beginPath()
            for (x = 0; x <= w; x += g) {
                if (Math.round(x) % major === 0)
                    continue
                ctx.moveTo(x + 0.5, 0)
                ctx.lineTo(x + 0.5, h)
            }
            for (y = 0; y <= h; y += g) {
                if (Math.round(y) % major === 0)
                    continue
                ctx.moveTo(0, y + 0.5)
                ctx.lineTo(w, y + 0.5)
            }
            ctx.stroke()
            ctx.strokeStyle = "#28FFFFFF"
            ctx.beginPath()
            for (x = 0; x <= w; x += major) {
                ctx.moveTo(x + 0.5, 0)
                ctx.lineTo(x + 0.5, h)
            }
            for (y = 0; y <= h; y += major) {
                ctx.moveTo(0, y + 0.5)
                ctx.lineTo(w, y + 0.5)
            }
            ctx.stroke()
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
                var sel = _ed.interactive && _ed.isSelected(n.id)
                ctx.strokeStyle = sel ? "#FBBF24" : "#A1A1AA"
                ctx.lineWidth = sel ? 1.6 : 1.1
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                var pts = _ed.pathPts(n)
                _ed.strokeLeader(ctx, n, pts)
                var hot = _ed.hotPt(n)
                var hs = _ed.hotSz(n)
                var hShape = n.hotShape || "round"
                var hFill = n.hotFill || "filled"
                _ed.drawMark(ctx, hot.x, hot.y, hs, hShape, hFill, sel ? "#FBBF24" : "#F4F4F5")
                if (_ed.interactive) {
                    var a = _ed.endPt(_ed.fromEnd(n))
                    _ed.drawMark(ctx, a.x, a.y, 8, "round", "filled", sel ? "#38BDF8" : "#64748B")
                    var te = _ed.toEnd(n)
                    if (te.type !== "hot") {
                        var tp = _ed.endPt(te)
                        _ed.drawMark(ctx, tp.x, tp.y, 8, "round", "filled", sel ? "#FB923C" : "#94A3B8")
                    }
                    var spines = n.spines || []
                    for (var s = 0; s < spines.length; s++) {
                        var sx = spines[s].fx * width
                        var sy = spines[s].fy * height
                        ctx.beginPath()
                        ctx.arc(sx, sy, 5, 0, 6.3)
                        ctx.fillStyle = (sel && _ed.selectedSpine === s) ? "#F59E0B" : "#94A3B8"
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
        hoverEnabled: true
        preventStealing: true
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
            var shift = (m.modifiers & Qt.ShiftModifier) || (m.modifiers & Qt.ControlModifier)
            if (m.button === Qt.RightButton && hit.kind === "spine") {
                var n = _ed.nodeAt(hit.id)
                if (n && n.spines) {
                    n.spines.splice(hit.spine, 1)
                    _ed.selectedSpine = -1
                    _ed.bump()
                }
                return
            }
            if (hit.kind === "line" && !shift) {
                _ed.addSpineAt(hit.id, m.x, m.y)
                return
            }
            if (hit.kind === "from" || hit.kind === "to") {
                if (!shift)
                    _ed.setSelection([hit.id])
                _ed.selectedId = hit.id
                _ed.selectedSpine = -1
                _ed.dragKind = hit.kind
                var ne = _ed.nodeAt(hit.id)
                if (ne) {
                    var ep = _ed.endPt(hit.kind === "to" ? _ed.toEnd(ne) : _ed.fromEnd(ne))
                    var fr = { type: "free", fx: ep.x / Math.max(1, width), fy: ep.y / Math.max(1, height) }
                    if (hit.kind === "to") ne.to = fr
                    else ne.from = fr
                }
                _ed.bump()
                return
            }
            if (hit.kind === "chip") {
                if (shift)
                    _ed.toggleSelected(hit.id)
                else if (!_ed.isSelected(hit.id))
                    _ed.setSelection([hit.id])
                _ed.selectedId = hit.id
                _ed.selectedSpine = -1
                _ed.dragKind = "chip"
                _ed.dragSpine = -1
                var n2 = _ed.nodeAt(hit.id)
                if (n2) {
                    _ed.dragOffX = m.x - n2.chipFx * width
                    _ed.dragOffY = m.y - n2.chipFy * height
                }
                _ed.bump()
                return
            }
            if (hit.kind === "hot" || hit.kind === "spine") {
                if (!shift)
                    _ed.setSelection([hit.id])
                _ed.selectedId = hit.id
                _ed.selectedSpine = hit.spine
                _ed.dragKind = hit.kind
                _ed.dragSpine = hit.spine
                _ed.bump()
                return
            }
            _ed.dragKind = "band"
            _ed.banding = false
            _ed.bandAdd = shift
            _ed.bandX0 = m.x
            _ed.bandY0 = m.y
            _ed.bandX1 = m.x
            _ed.bandY1 = m.y
            if (!shift)
                _ed.setSelection([])
            _ed.bump()
        }
        onPositionChanged: (m) => {
            if (!_ed.dragKind) {
                return
            }
            if (_ed.dragKind === "band") {
                _ed.bandX1 = m.x
                _ed.bandY1 = m.y
                if (!_ed.banding && Math.hypot(m.x - _ed.bandX0, m.y - _ed.bandY0) > 4)
                    _ed.banding = true
                return
            }
            var n = _ed.nodeAt(_ed.selectedId)
            if (!n) {
                return
            }
            var altOff = !!(m.modifiers & Qt.AltModifier)
            if (_ed.dragKind === "from" || _ed.dragKind === "to") {
                var ep2 = _ed.snapPos(m.x, m.y, altOff)
                var fr2 = { type: "free", fx: ep2.x / Math.max(1, width), fy: ep2.y / Math.max(1, height) }
                if (_ed.dragKind === "to") n.to = fr2
                else n.from = fr2
            } else if (_ed.dragKind === "hot") {
                var hp = _ed.snapPos(m.x, m.y, altOff)
                var p = _ed.toPhoto(hp.x, hp.y)
                n.nx = Math.max(0, Math.min(1, p.x))
                n.ny = Math.max(0, Math.min(1, p.y))
            } else if (_ed.dragKind === "chip") {
                var cp = _ed.snapPos(m.x - _ed.dragOffX, m.y - _ed.dragOffY, altOff)
                var fx = Math.max(0.01, Math.min(0.92, cp.x / Math.max(1, width)))
                var fy = Math.max(0.01, Math.min(0.92, cp.y / Math.max(1, height)))
                var dFx = fx - n.chipFx
                var dFy = fy - n.chipFy
                var ids = (_ed.selectedIds && _ed.selectedIds.length) ? _ed.selectedIds : [_ed.selectedId]
                for (var i = 0; i < ids.length; i++) {
                    var q = _ed.nodeAt(ids[i])
                    if (!q)
                        continue
                    q.chipFx = Math.max(0.01, Math.min(0.92, q.chipFx + dFx))
                    q.chipFy = Math.max(0.01, Math.min(0.92, q.chipFy + dFy))
                }
            } else if (_ed.dragKind === "spine" && n.spines && _ed.dragSpine >= 0) {
                var sp = _ed.snapPos(m.x, m.y, altOff)
                n.spines[_ed.dragSpine].fx = Math.max(0, Math.min(1, sp.x / Math.max(1, width)))
                n.spines[_ed.dragSpine].fy = Math.max(0, Math.min(1, sp.y / Math.max(1, height)))
            }
            _ed.repaint()
        }
        onReleased: (m) => {
            if (_ed.dragKind === "band") {
                if (_ed.banding)
                    _ed.selectBand(_ed.bandAdd)
                _ed.banding = false
                _ed.dragKind = ""
                _ed.bump()
                return
            }
            if (_ed.dragKind === "from" || _ed.dragKind === "to") {
                var n3 = _ed.nodeAt(_ed.selectedId)
                if (n3) {
                    var hooked = _ed.attachNear(m.x, m.y)
                    if (_ed.dragKind === "to") n3.to = hooked
                    else {
                        n3.from = hooked
                        if (hooked.type === "chip" && hooked.id === n3.id)
                            n3.pin = hooked.pin || n3.pin
                    }
                }
                _ed.dragKind = ""
                _ed.bump()
                return
            }
            if (_ed.dragKind) {
                _ed.dragKind = ""
                _ed.bump()
            }
        }
        onDoubleClicked: (m) => {
            var hit = _ed.hitTest(m.x, m.y)
            if (hit.kind === "line" || hit.kind === "hot") {
                _ed.addSpineAt(hit.id || _ed.selectedId, m.x, m.y)
            }
        }
        onWheel: (w) => {
            if (!_ed.interactive || !face || !face.zoomAt) {
                w.accepted = false
                return
            }
            var dy = w.pixelDelta.y !== 0 ? w.pixelDelta.y : w.angleDelta.y
            if (dy === 0) {
                w.accepted = false
                return
            }
            var vx = w.x * face.zoom + face.panX
            var vy = w.y * face.zoom + face.panY
            face.zoomAt(vx, vy, Math.pow(1.0012, dy))
            w.accepted = true
        }
    }

    Rectangle {
        visible: _ed.banding
        x: Math.min(_ed.bandX0, _ed.bandX1)
        y: Math.min(_ed.bandY0, _ed.bandY1)
        width: Math.abs(_ed.bandX1 - _ed.bandX0)
        height: Math.abs(_ed.bandY1 - _ed.bandY0)
        z: 9
        color: "#33FBBF24"
        border.color: "#FBBF24"
        border.width: 1
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 6
        z: 9
        visible: _ed.interactive
        color: "#A1A1AA"
        font.pixelSize: 10
        text: "Grid snap in the toolbar. Alt-drag to ignore snap. Shift-click or drag-box to multi-select."
    }
}
