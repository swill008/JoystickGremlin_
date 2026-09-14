// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQml
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
    property bool snapEntOn: true
    property int gridSize: 8
    property bool altHeld: false
    property bool shiftHeld: false
    property string groupEditId: ""
    property int selectedMember: -1
    property int dragMember: -1
    property int selectedLeader: 0
    property int selectedSeg: -1
    property int dragLeader: 0
    property string drawTool: ""
    property real drawX0: 0
    property real drawY0: 0
    property real drawX1: 0
    property real drawY1: 0
    property real rzX0: 0
    property real rzY0: 0
    property real rzX1: 0
    property real rzY1: 0
    property var clip: []
    signal selectedChanged()
    signal chipMenuRequested(real x, real y)
    signal historyChanged()
    signal colorPickRequested(string field, string hex)

    property var hist
    property int histAt: -1
    property int histCap: 80
    property bool _restoring: false
    readonly property bool canUndo: histAt > 0
    readonly property bool canRedo: histAt >= 0 && hist && histAt < hist.length - 1

    // Do NOT declare signal nodesChanged — property var nodes already has it.

    function repaint() {
        tick++
        if (_lines)
            _lines.requestPaint()
    }

    function bump() {
        repaint()
        selectedChanged()
        if (!_restoring)
            pushHist()
    }

    function snapJson() {
        try {
            return JSON.stringify(nodes || [])
        } catch (e) {
            return "[]"
        }
    }

    function seedHist() {
        hist = [snapJson()]
        histAt = 0
        historyChanged()
    }

    function pushHist() {
        if (_restoring || !interactive)
            return
        var s = snapJson()
        var cur = hist || []
        if (histAt >= 0 && histAt < cur.length && cur[histAt] === s)
            return
        var next = cur.slice(0, histAt + 1)
        next.push(s)
        if (next.length > histCap)
            next = next.slice(next.length - histCap)
        hist = next
        histAt = next.length - 1
        historyChanged()
    }

    function applySnap(s) {
        var next = []
        try {
            next = JSON.parse(s)
        } catch (e) {
            return
        }
        var list = nodes
        if (!list)
            return
        list.splice(0, list.length)
        for (var i = 0; i < next.length; i++)
            list.push(next[i])
    }

    function undo() {
        if (!canUndo)
            return
        histAt = histAt - 1
        _restoring = true
        applySnap(hist[histAt])
        groupEditId = ""
        selectedMember = -1
        setSelection([])
        historyChanged()
        bump()
        _restoring = false
    }

    function redo() {
        if (!canRedo)
            return
        histAt = histAt + 1
        _restoring = true
        applySnap(hist[histAt])
        groupEditId = ""
        selectedMember = -1
        setSelection([])
        historyChanged()
        bump()
        _restoring = false
    }

    function clearLayout() {
        setSelection([])
        groupEditId = ""
        selectedMember = -1
        selectedLeader = 0
        selectedSeg = -1
        dragKind = ""
        bump()
    }

    function applyPointer(mx, my, altOff) {
        if (!dragKind || dragKind === "band")
            return
        var n = nodeAt(selectedId)
        if (!n)
            return
        if (dragKind === "from" || dragKind === "to") {
            var ep2 = snapPos(mx, my, altOff)
            var fr2 = { type: "free", fx: ep2.x / Math.max(1, width), fy: ep2.y / Math.max(1, height) }
            var Ld = currentLeader(n)
            if (!Ld)
                return
            if (dragKind === "to") Ld.to = fr2
            else Ld.from = fr2
            if (selectedLeader === 0) {
                if (dragKind === "to") n.to = fr2
                else n.from = fr2
            }
        } else if (dragKind === "hot") {
            var hp = snapPos(mx, my, altOff)
            var p = toPhoto(hp.x, hp.y)
            n.nx = Math.max(0, Math.min(1, p.x))
            n.ny = Math.max(0, Math.min(1, p.y))
        } else if (dragKind === "chip") {
            var cp = snapPos(mx - dragOffX, my - dragOffY, altOff)
            var fx = Math.max(0.01, Math.min(0.92, cp.x / Math.max(1, width)))
            var fy = Math.max(0.01, Math.min(0.92, cp.y / Math.max(1, height)))
            var dFx = fx - n.chipFx
            var dFy = fy - n.chipFy
            var ids = (selectedIds && selectedIds.length) ? selectedIds : [selectedId]
            for (var i = 0; i < ids.length; i++) {
                var q = nodeAt(ids[i])
                if (!q)
                    continue
                q.chipFx = Math.max(0.01, Math.min(0.92, q.chipFx + dFx))
                q.chipFy = Math.max(0.01, Math.min(0.92, q.chipFy + dFy))
            }
        } else if (dragKind === "spine" && dragSpine >= 0) {
            var Ls = currentLeader(n)
            if (!Ls)
                return
            if (!Ls.spines) Ls.spines = []
            if (dragSpine < Ls.spines.length) {
                var sp = snapPos(mx, my, altOff)
                Ls.spines[dragSpine].fx = Math.max(0, Math.min(1, sp.x / Math.max(1, width)))
                Ls.spines[dragSpine].fy = Math.max(0, Math.min(1, sp.y / Math.max(1, height)))
            }
            n.spines = Ls.spines
        } else if (dragKind === "draw") {
            var g0 = drawGeom(n)
            var np = snapEnt(mx - dragOffX, my - dragOffY, altOff)
            var ddx = np.x - g0.x
            var ddy = np.y - g0.y
            var around = n.around || []
            if (around.length) {
                var ai
                for (ai = 0; ai < around.length; ai++) {
                    var qn = nodeAt(around[ai])
                    if (!qn || isDraw(qn))
                        continue
                    qn.chipFx = Math.max(0.01, Math.min(0.92, qn.chipFx + ddx / Math.max(1, width)))
                    qn.chipFy = Math.max(0.01, Math.min(0.92, qn.chipFy + ddy / Math.max(1, height)))
                }
            } else {
                n.fx = Math.max(0, Math.min(0.98, np.x / Math.max(1, width)))
                n.fy = Math.max(0, Math.min(0.98, np.y / Math.max(1, height)))
            }
        } else if (dragKind.indexOf("draw-") === 0) {
            applyDrawResize(n, mx, my, dragKind.slice(5), altOff)
        } else if (dragKind === "member" && n.members && dragMember >= 0 && dragMember < n.members.length) {
            bakeAlignToFree(n)
            var mp = snapPos(mx - dragOffX, my - dragOffY, altOff)
            n.members[dragMember].ox = mp.x / Math.max(1, width) - n.chipFx
            n.members[dragMember].oy = mp.y / Math.max(1, height) - n.chipFy
        }
        repaint()
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

    function fieldEq(key, val, fallback) {
        var n = nodeAt(selectedId)
        if (!n)
            return val === fallback
        var cur = n[key]
        if (cur === undefined || cur === null || cur === "")
            return val === fallback
        return cur === val
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
            groupEditId = ""
            selectedMember = -1
            dragMember = -1
        } else {
            Qt.callLater(seedHist)
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
            return face.labelAxis(hwId)
        }
        if (kind === "hat") {
            return face.labelHat(hwId)
        }
        return face.labelBtn(hwId)
    }

    // Physical names from the EVO R lock inventory. Shown as default friendly names.
    readonly property var physNames: ({
        "btn:1": "Red trigger half",
        "btn:2": "Red trigger full",
        "btn:3": "Red head button",
        "btn:4": "White cap",
        "btn:5": "Lower grip white",
        "btn:6": "Head 5-way (right of red) up",
        "btn:7": "Head 5-way (right of red) right",
        "btn:8": "Head 5-way (right of red) down",
        "btn:9": "Head 5-way (right of red) left",
        "btn:10": "Head 5-way (right of red) center",
        "btn:11": "Top-right head 5-way up",
        "btn:12": "Top-right head 5-way right",
        "btn:13": "Top-right head 5-way down",
        "btn:14": "Top-right head 5-way left",
        "btn:15": "Top-right head 5-way center",
        "btn:16": "Silver wheel 5-way up",
        "btn:17": "Silver wheel 5-way right",
        "btn:18": "Silver wheel 5-way down",
        "btn:19": "Silver wheel 5-way left",
        "btn:20": "Silver wheel 5-way center",
        "btn:21": "Grey paddle push",
        "btn:22": "Grey paddle pull",
        "btn:23": "En2 right knob up",
        "btn:24": "En2 right knob down",
        "btn:25": "En1 left knob up",
        "btn:26": "En1 left knob down",
        "btn:27": "Middle base pad",
        "btn:28": "Left base pad",
        "btn:29": "Right base pad",
        "hat:1": "Analog ministick",
        "axis:1": "Stick X roll",
        "axis:2": "Stick Y pitch",
        "axis:3": "Stick Z twist",
        "axis:4": "Z slider (En1–En2)"
    })

    function leafKind(kind) {
        if (kind === "axis_stack")
            return "axis"
        if (kind === "plus" || kind === "pair" || kind === "stack")
            return "btn"
        return kind || "btn"
    }

    function physicalName(kind, hwId) {
        var k = leafKind(kind) + ":" + hwId
        return physNames[k] || ""
    }

    function defaultFriendly(kind, hwId) {
        var p = physicalName(kind, hwId)
        if (p.length)
            return p
        var lk = leafKind(kind)
        if (lk === "axis")
            return "Axis " + hwId
        if (lk === "hat")
            return "Hat " + hwId
        return "Button " + hwId
    }

    function friendlyOf(n, mem) {
        if (mem) {
            if (mem.friendly && String(mem.friendly).length)
                return mem.friendly
            var lk = (n && n.kind === "axis_stack") ? "axis" : "btn"
            return defaultFriendly(lk, mem.hwId)
        }
        if (!n)
            return ""
        if (n.friendly && String(n.friendly).length)
            return n.friendly
        if (n.label && String(n.label).length)
            return n.label
        if (isGroup(n))
            return n.id
        return defaultFriendly(n.kind, n.hwId)
    }

    function fullNameOf(kind, hwId) {
        var lk = leafKind(kind)
        var idn = lk === "axis" ? ("Axis " + hwId) : (lk === "hat" ? ("Hat " + hwId) : ("Button " + hwId))
        var phys = physicalName(lk, hwId)
        var dest = destOf(lk, hwId)
        var s = idn
        if (phys.length)
            s += " · " + phys
        if (dest && dest !== "—")
            s += " → " + dest
        return s
    }

    function placedId(kind, hwId) {
        var want = leafKind(kind) + ":" + hwId
        var list = nodes || []
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            if (isGroup(n)) {
                var mem = n.members || []
                var lk = n.kind === "axis_stack" ? "axis" : "btn"
                for (var j = 0; j < mem.length; j++) {
                    if (lk + ":" + mem[j].hwId === want)
                        return n.id
                }
            } else if (leafKind(n.kind) + ":" + n.hwId === want) {
                return n.id
            }
        }
        return ""
    }

    function catalog() {
        tick
        var seen = {}
        var items = []
        function add(kind, hwId) {
            var key = kind + ":" + hwId
            if (seen[key])
                return
            seen[key] = true
            var pid = placedId(kind, hwId)
            var lk = leafKind(kind)
            var hwName = lk === "axis" ? ("Axis " + hwId) : (lk === "hat" ? ("Hat " + hwId) : ("Button " + hwId))
            items.push({
                kind: kind,
                hwId: hwId,
                key: key,
                friendly: defaultFriendly(kind, hwId),
                hwName: hwName,
                dest: destOf(lk, hwId),
                fullName: fullNameOf(kind, hwId),
                placed: pid.length > 0,
                placedId: pid
            })
        }
        var i
        for (i = 1; i <= 29; i++)
            add("btn", i)
        add("hat", 1)
        for (i = 1; i <= 4; i++)
            add("axis", i)
        function extras(map, kind) {
            if (!map)
                return
            for (var k in map) {
                var id = parseInt(k, 10)
                if (id > 0)
                    add(kind, id)
            }
        }
        if (face) {
            extras(face.destBtn, "btn")
            extras(face.destAxis, "axis")
            extras(face.destHat, "hat")
        }
        return items
    }

    function viewCenterPhoto() {
        if (!face || !face.toPhoto)
            return Qt.point(0.5, 0.5)
        var z = face.zoom || 1
        if (z < 0.01)
            z = 1
        var wx = ((face.width || width) * 0.5 - (face.panX || 0)) / z
        var wy = ((face.height || height) * 0.5 - (face.panY || 0)) / z
        return toPhoto(wx, wy)
    }

    function addChiplet(kind, hwId, wx, wy) {
        kind = leafKind(kind)
        hwId = parseInt(hwId, 10)
        if (!(hwId > 0))
            return
        var existing = placedId(kind, hwId)
        if (existing) {
            setSelection([existing])
            bump()
            return
        }
        var p
        if (wx !== undefined && wy !== undefined && wx !== null && wy !== null)
            p = toPhoto(wx, wy)
        else
            p = viewCenterPhoto()
        var st = _styleOf({})
        var n = {
            id: _uid(kind === "btn" ? "b" : kind.charAt(0)),
            kind: kind,
            hwId: hwId,
            prefix: kind === "axis" ? "A" : (kind === "hat" ? "H" : ""),
            label: "",
            friendly: defaultFriendly(kind, hwId),
            nx: Math.max(0.02, Math.min(0.98, p.x)),
            ny: Math.max(0.02, Math.min(0.98, p.y)),
            chipFx: Math.max(0.04, Math.min(0.92, p.x)),
            chipFy: Math.max(0.04, Math.min(0.94, p.y)),
            pin: p.x < 0.5 ? "right" : "left",
            spines: [],
            curve: st.curve,
            color: st.color,
            border: st.border,
            textColor: st.textColor,
            highlight: st.highlight,
            hlColor: st.hlColor,
            hlBorder: st.hlBorder,
            hlText: st.hlText,
            fontSize: st.fontSize,
            chipSize: st.chipSize,
            chipShape: st.chipShape,
            chipFill: st.chipFill,
            hotSize: st.hotSize,
            hotShape: st.hotShape,
            hotFill: st.hotFill
        }
        var list = nodes || []
        list.push(n)
        setSelection([n.id])
        bump()
    }

    function ensureFriendly(n) {
        if (!n)
            return
        if (isGroup(n)) {
            var mem = n.members || []
            var lk = n.kind === "axis_stack" ? "axis" : "btn"
            for (var i = 0; i < mem.length; i++) {
                if (!mem[i].friendly || !String(mem[i].friendly).length)
                    mem[i].friendly = defaultFriendly(lk, mem[i].hwId)
            }
            if (!n.friendly || !String(n.friendly).length)
                n.friendly = n.label && n.label.length ? n.label : n.id
        } else if (isDraw(n)) {
            if (!n.friendly || !String(n.friendly).length)
                n.friendly = "Draw"
        } else if (!n.friendly || !String(n.friendly).length) {
            n.friendly = (n.label && n.label.length) ? n.label : defaultFriendly(n.kind, n.hwId)
        }
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

    function _legacyLeader(n) {
        return {
            id: ((n && n.id) ? n.id : "n") + "_L0",
            from: fromEnd(n),
            to: toEnd(n),
            spines: (n && n.spines) ? n.spines : [],
            curve: n ? n.curve : true,
            fromCurve: n ? n.fromCurve : undefined
        }
    }

    function leaderList(n) {
        if (!n || n.kind === "draw")
            return []
        if (n.leaders)
            return n.leaders
        return [_legacyLeader(n)]
    }

    function ensureLeaders(n) {
        if (!n || n.kind === "draw")
            return []
        if (n.leaders === undefined || n.leaders === null)
            n.leaders = [_legacyLeader(n)]
        return n.leaders
    }

    function currentLeader(n) {
        var ls = ensureLeaders(n)
        if (!ls.length)
            return null
        var i = selectedLeader
        if (i < 0 || i >= ls.length)
            i = 0
        return ls[i]
    }

    function pathPtsL(L) {
        if (!L)
            return []
        var pts = [endPt(L.from)]
        var spines = L.spines || []
        for (var s = 0; s < spines.length; s++) {
            pts.push(Qt.point(spines[s].fx * width, spines[s].fy * height))
        }
        pts.push(endPt(L.to))
        return pts
    }

    function pathPts(n) {
        return pathPtsL(leaderList(n)[0])
    }

    function segIsCurve(L, j) {
        if (!L)
            return true
        if (j <= 0) {
            if (L.fromCurve !== undefined)
                return L.fromCurve !== false
            return L.curve !== false
        }
        var sp = (L.spines || [])[j - 1]
        if (sp && sp.curve !== undefined)
            return sp.curve !== false
        return L.curve !== false
    }

    function setSegCurve(L, j, on) {
        if (!L)
            return
        if (j <= 0)
            L.fromCurve = on
        else if (L.spines && L.spines[j - 1])
            L.spines[j - 1].curve = on
        bump()
    }

    function toggleSegCurve() {
        var n = nodeAt(selectedId)
        if (!n)
            return
        var L = currentLeader(n)
        if (!L)
            return
        var j = selectedSeg
        if (j < 0)
            j = (selectedSpine >= 0) ? (selectedSpine + 1) : 0
        setSegCurve(L, j, !segIsCurve(L, j))
    }

    function setAllSegCurve(on) {
        var n = nodeAt(selectedId)
        if (!n)
            return
        var L = currentLeader(n)
        if (!L)
            return
        L.curve = on
        L.fromCurve = on
        var s = L.spines || []
        for (var i = 0; i < s.length; i++)
            s[i].curve = on
        if (selectedLeader === 0)
            n.curve = on
        bump()
    }

    function addLeader() {
        var n = nodeAt(selectedId)
        if (!n)
            return
        var ls = ensureLeaders(n)
        var src = ls.length ? (ls[selectedLeader] || ls[0]) : null
        if (!src) {
            ls.push(_legacyLeader(n))
            selectedLeader = 0
            bump()
            return
        }
        var a = endPt(src.from)
        ls.push({
            id: _uid("L"),
            from: {
                type: src.from && src.from.type ? src.from.type : "chip",
                id: src.from ? src.from.id : n.id,
                pin: src.from ? src.from.pin : (n.pin || "right"),
                fx: src.from ? src.from.fx : 0,
                fy: src.from ? src.from.fy : 0
            },
            to: {
                type: "free",
                fx: Math.max(0.02, Math.min(0.95, (a.x + 48) / Math.max(1, width))),
                fy: Math.max(0.02, Math.min(0.95, (a.y + 36) / Math.max(1, height)))
            },
            spines: [],
            curve: false,
            fromCurve: false
        })
        selectedLeader = ls.length - 1
        selectedSeg = 0
        bump()
    }

    function addBranch() {
        var n = nodeAt(selectedId)
        if (!n)
            return
        var ls = ensureLeaders(n)
        var src = ls.length ? (ls[selectedLeader] || ls[0]) : null
        if (!src)
            return
        var origin = (src.to && src.to.type === "free") ? src.to : src.from
        var p = endPt(origin)
        ls.push({
            id: _uid("L"),
            from: {
                type: origin && origin.type ? origin.type : "free",
                id: origin ? origin.id : "",
                pin: origin ? origin.pin : "",
                fx: origin ? origin.fx : (p.x / Math.max(1, width)),
                fy: origin ? origin.fy : (p.y / Math.max(1, height))
            },
            to: {
                type: "free",
                fx: Math.max(0.02, Math.min(0.95, (p.x + 56) / Math.max(1, width))),
                fy: Math.max(0.02, Math.min(0.95, (p.y - 44) / Math.max(1, height)))
            },
            spines: [],
            curve: true,
            fromCurve: true
        })
        selectedLeader = ls.length - 1
        selectedSeg = 0
        bump()
    }

    function deleteLeader() {
        var n = nodeAt(selectedId)
        if (!n)
            return
        var ls = ensureLeaders(n)
        if (!ls.length)
            return
        var i = selectedLeader
        if (i < 0 || i >= ls.length)
            i = 0
        ls.splice(i, 1)
        n.leaders = ls
        if (ls.length) {
            selectedLeader = Math.min(i, ls.length - 1)
            var L = ls[selectedLeader]
            n.spines = L.spines || []
            n.from = L.from
            n.to = L.to
        } else {
            selectedLeader = 0
            selectedSpine = -1
            n.spines = []
            n.from = undefined
            n.to = undefined
        }
        bump()
    }

    function groupAlignH(n) {
        var a = n && n.alignH ? String(n.alignH) : "left"
        if (a === "center" || a === "right" || a === "free")
            return a
        return "left"
    }

    function setAlignH(mode) {
        var n = nodeAt(selectedId)
        if (!isGroup(n))
            return
        if (mode === "free")
            bakeAlignToFree(n)
        else
            n.alignH = (mode === "left" || mode === "right") ? mode : "center"
        bump()
    }

    function bakeAlignToFree(n) {
        if (!isGroup(n) || groupAlignH(n) === "free")
            return
        var mem = n.members || []
        var ew = Math.max(1, _ed.width)
        var eh = Math.max(1, _ed.height)
        for (var i = 0; i < mem.length; i++) {
            mem[i].ox = memberLocalX(n, mem[i]) / ew
            mem[i].oy = memberLocalY(n, mem[i]) / eh
        }
        n.alignH = "free"
    }

    function memberIndexOf(n, mem) {
        var mems = (n && n.members) ? n.members : []
        for (var i = 0; i < mems.length; i++) {
            if (mems[i] === mem)
                return i
        }
        return 0
    }

    function stackPitch(n) {
        return chipH(n) + 2
    }

    function memberLocalX(n, mem) {
        var ew = Math.max(1, _ed.width)
        var a = groupAlignH(n)
        var w = chipWGuess(n, mem)
        var span = groupSpanW(n)
        if (a === "center")
            return Math.max(0, (span - w) * 0.5)
        if (a === "right")
            return Math.max(0, span - w)
        if (a === "left")
            return 0
        return (mem.ox || 0) * ew - groupMinX(n)
    }

    function memberLocalY(n, mem) {
        if (groupAlignH(n) !== "free")
            return memberIndexOf(n, mem) * stackPitch(n)
        var eh = Math.max(1, _ed.height)
        return (mem.oy || 0) * eh - groupMinY(n)
    }

    function groupMinX(n) {
        if (groupAlignH(n) !== "free")
            return 0
        var mem = (n && n.members) ? n.members : []
        var ew = Math.max(1, _ed.width)
        var minx = 1e9
        for (var i = 0; i < mem.length; i++)
            minx = Math.min(minx, (mem[i].ox || 0) * ew)
        return minx < 1e8 ? minx : 0
    }

    function groupMinY(n) {
        if (groupAlignH(n) !== "free")
            return 0
        var mem = (n && n.members) ? n.members : []
        var eh = Math.max(1, _ed.height)
        var miny = 1e9
        for (var i = 0; i < mem.length; i++)
            miny = Math.min(miny, (mem[i].oy || 0) * eh)
        return miny < 1e8 ? miny : 0
    }

    function groupSpanW(n) {
        var mem = (n && n.members) ? n.members : []
        if (!mem.length)
            return 40
        if (groupAlignH(n) !== "free") {
            var maxw = 8
            for (var i = 0; i < mem.length; i++)
                maxw = Math.max(maxw, chipWGuess(n, mem[i]))
            return maxw
        }
        var ew = Math.max(1, _ed.width)
        var minx = groupMinX(n)
        var maxx = minx
        for (var j = 0; j < mem.length; j++)
            maxx = Math.max(maxx, (mem[j].ox || 0) * ew + chipWGuess(n, mem[j]))
        return Math.max(8, maxx - minx)
    }

    function groupSpanH(n) {
        var mem = (n && n.members) ? n.members : []
        if (!mem.length)
            return 20
        if (groupAlignH(n) !== "free")
            return Math.max(8, mem.length * stackPitch(n) - 2)
        var eh = Math.max(1, _ed.height)
        var miny = groupMinY(n)
        var maxy = miny
        for (var i = 0; i < mem.length; i++)
            maxy = Math.max(maxy, (mem[i].oy || 0) * eh + chipH(n))
        return Math.max(8, maxy - miny)
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
        var L = currentLeader(n)
        if (!L)
            return
        var p = endPt(which === "to" ? L.to : L.from)
        var free = { type: "free", fx: p.x / Math.max(1, width), fy: p.y / Math.max(1, height) }
        if (which === "to") L.to = free
        else L.from = free
        if (selectedLeader === 0) {
            if (which === "to") n.to = free
            else n.from = free
        }
        bump()
    }

    function attachEndToSelf(which) {
        var n = nodeAt(selectedId)
        if (!n) return
        var L = currentLeader(n)
        if (!L)
            return
        if (which === "to") L.to = { type: "hot", id: n.id }
        else L.from = { type: "chip", id: n.id, pin: n.pin || "right" }
        if (selectedLeader === 0) {
            n.to = L.to
            n.from = L.from
        }
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

    function strokeLeader(ctx, n, pts, L) {
        if (!pts || pts.length < 2) return
        if (!L)
            L = leaderList(n)[0]
        ctx.beginPath()
        ctx.moveTo(pts[0].x, pts[0].y)
        for (var j = 0; j < pts.length - 1; j++) {
            if (pts.length > 2 && segIsCurve(L, j)) {
                var c = _bezierCtrl(pts, j)
                ctx.bezierCurveTo(c.c1x, c.c1y, c.c2x, c.c2y, c.x, c.y)
            } else {
                ctx.lineTo(pts[j + 1].x, pts[j + 1].y)
            }
        }
        ctx.stroke()
    }

    function ensureMidSpine(n) {
        if (!n || n.kind === "draw")
            return
        if (n.spines && n.spines.length) {
            return
        }
        var L = currentLeader(n)
        if (!L)
            return
        var a = endPt(L.from)
        var b = endPt(L.to)
        if (L.spines && L.spines.length)
            return
        L.spines = [{ fx: ((a.x + b.x) * 0.5) / Math.max(1, width), fy: ((a.y + b.y) * 0.5) / Math.max(1, height), curve: L.curve !== false }]
        n.spines = L.spines
    }

    function addCurveSpine(n) {
        if (!n) return
        var L = currentLeader(n)
        if (!L)
            return
        L.curve = true
        var a = endPt(L.from)
        var b = endPt(L.to)
        var spines = L.spines || []
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
        if (!L.spines) L.spines = []
        L.spines.push({ fx: (mx + ox) / Math.max(1, width), fy: (my + oy) / Math.max(1, height), curve: true })
        n.spines = L.spines
        selectedId = n.id
        selectedSpine = L.spines.length - 1
        selectedLeader = Math.max(0, selectedLeader)
        selectedChanged()
        bump()
    }

    function hitTest(mx, my) {
        var list = nodes || []
        var i
        var n
        for (i = 0; i < list.length; i++) {
            n = list[i]
            if (n.kind === "draw")
                continue
            var ls = leaderList(n)
            for (var li = 0; li < ls.length; li++) {
                var fp = endPt(ls[li].from)
                if (Math.hypot(mx - fp.x, my - fp.y) < 9) {
                    return { kind: "from", id: n.id, spine: -1, leader: li }
                }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            var ls2 = leaderList(n)
            for (var lj = 0; lj < ls2.length; lj++) {
                var te = ls2[lj].to || { type: "hot", id: n.id }
                var tp = endPt(te)
                if (te.type !== "hot" && Math.hypot(mx - tp.x, my - tp.y) < 9) {
                    return { kind: "to", id: n.id, spine: -1, leader: lj }
                }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            if (n.kind === "draw")
                continue
            var h = hotPt(n)
            if (Math.hypot(mx - h.x, my - h.y) < (hotSz(n) * 0.5 + 5)) {
                return { kind: "hot", id: n.id, spine: -1 }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            var lss = leaderList(n)
            for (var lk = 0; lk < lss.length; lk++) {
                var spines = lss[lk].spines || []
                for (var s = 0; s < spines.length; s++) {
                    var sx = spines[s].fx * width
                    var sy = spines[s].fy * height
                    if (Math.hypot(mx - sx, my - sy) < 9) {
                        return { kind: "spine", id: n.id, spine: s, leader: lk }
                    }
                }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            if (isGroup(n) && groupEditId === n.id) {
                var mi = memberHit(n, mx, my)
                if (mi >= 0)
                    return { kind: "member", id: n.id, spine: -1, member: mi }
            }
        }
        for (i = 0; i < list.length; i++) {
            n = list[i]
            if (isDraw(n))
                continue
            if (isGroup(n) && memberHit(n, mx, my) >= 0)
                return { kind: "chip", id: n.id, spine: -1 }
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
            n = list[i]
            if (!isDraw(n))
                continue
            var dh = hitDraw(n, mx, my)
            if (dh)
                return { kind: "draw", id: n.id, spine: -1, handle: dh }
        }
        for (i = 0; i < list.length; i++) {
            var seg = _nearLeader(list[i], mx, my)
            if (seg && seg.seg >= 0) {
                return { kind: "line", id: list[i].id, spine: -1, leader: seg.leader, seg: seg.seg }
            }
        }
        return { kind: "", id: "", spine: -1 }
    }

    function _nearLeader(n, mx, my) {
        var ls = leaderList(n)
        var best = { leader: -1, seg: -1 }
        var bestD = 6
        var li
        for (li = 0; li < ls.length; li++) {
            var L = ls[li]
            var pts = pathPtsL(L)
            if (pts.length < 2)
                continue
            for (var j = 0; j < pts.length - 1; j++) {
                var d
                if (pts.length > 2 && segIsCurve(L, j)) {
                    d = _distBezier(mx, my, pts, j)
                } else {
                    d = _distSeg(mx, my, pts[j].x, pts[j].y, pts[j + 1].x, pts[j + 1].y)
                }
                if (d < bestD) {
                    bestD = d
                    best = { leader: li, seg: j }
                }
            }
        }
        return best
    }

    function _distBezier(mx, my, pts, j) {
        var c = _bezierCtrl(pts, j)
        var p1x = pts[j].x
        var p1y = pts[j].y
        var prevx = p1x
        var prevy = p1y
        var best = 1e9
        var steps = 8
        for (var s = 1; s <= steps; s++) {
            var tt = s / steps
            var u = 1 - tt
            var x = u*u*u*p1x + 3*u*u*tt*c.c1x + 3*u*tt*tt*c.c2x + tt*tt*tt*c.x
            var y = u*u*u*p1y + 3*u*u*tt*c.c1y + 3*u*tt*tt*c.c2y + tt*tt*tt*c.y
            var d = _distSeg(mx, my, prevx, prevy, x, y)
            if (d < best)
                best = d
            prevx = x
            prevy = y
        }
        return best
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
        var L = currentLeader(n)
        if (!L)
            return
        if (!L.spines)
            L.spines = []
        var pts = pathPtsL(L)
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
        var curved = segIsCurve(L, best)
        L.spines.splice(best, 0, { fx: spn.x / Math.max(1, width), fy: spn.y / Math.max(1, height), curve: curved })
        n.spines = L.spines
        selectedId = id
        selectedSpine = best
        selectedChanged()
        bump()
    }

    function deleteSelection() {
        var n = nodeAt(selectedId)
        if (!n)
            return
        var L = currentLeader(n)
        if (!L)
            return
        if (selectedSpine >= 0 && L.spines && selectedSpine < L.spines.length) {
            L.spines.splice(selectedSpine, 1)
            n.spines = L.spines
            selectedSpine = -1
            bump()
        }
    }

    function deleteChip(id) {
        var nid = id || selectedId
        var n = nodeAt(nid)
        if (!n || isGroup(n))
            return false
        var idx = nodeIndex(nid)
        if (idx < 0)
            return false
        var list = nodes || []
        list.splice(idx, 1)
        var keep = []
        var s = selectedIds || []
        for (var i = 0; i < s.length; i++) {
            if (s[i] !== nid)
                keep.push(s[i])
        }
        groupEditId = ""
        selectedMember = -1
        setSelection(keep)
        bump()
        return true
    }

    function isDraw(n) {
        return !!(n && n.kind === "draw")
    }

    function chipBounds(n) {
        if (!n)
            return { x: 0, y: 0, w: 40, h: 20 }
        var i = nodeIndex(n.id)
        var it = (i >= 0 && _chips) ? _chips.itemAt(i) : null
        if (it && it.width > 1)
            return { x: it.x, y: it.y, w: it.width, h: it.height }
        return {
            x: (n.chipFx || 0) * width,
            y: (n.chipFy || 0) * height,
            w: 80,
            h: chipH(n)
        }
    }

    function drawGeom(n) {
        var pad = (n && n.pad > 0) ? n.pad : 8
        var around = (n && n.around) ? n.around : []
        if (around.length) {
            var minx = 1e9
            var miny = 1e9
            var maxx = -1e9
            var maxy = -1e9
            var k
            for (k = 0; k < around.length; k++) {
                var q = nodeAt(around[k])
                if (!q || isDraw(q))
                    continue
                var b = chipBounds(q)
                minx = Math.min(minx, b.x)
                miny = Math.min(miny, b.y)
                maxx = Math.max(maxx, b.x + b.w)
                maxy = Math.max(maxy, b.y + b.h)
            }
            if (minx < 1e8)
                return { x: minx - pad, y: miny - pad, w: (maxx - minx) + pad * 2, h: (maxy - miny) + pad * 2 }
        }
        return {
            x: ((n && n.fx) ? n.fx : 0) * width,
            y: ((n && n.fy) ? n.fy : 0) * height,
            w: Math.max(8, ((n && n.fw) ? n.fw : 0.08) * width),
            h: Math.max(8, ((n && n.fh) ? n.fh : 0.06) * height)
        }
    }

    function snapEnt(x, y, altOff) {
        if (altOff)
            return Qt.point(x, y)
        if (!snapEntOn) {
            if (snapOn)
                return Qt.point(snapPx(x), snapPx(y))
            return Qt.point(x, y)
        }
        var xs = []
        var ys = []
        function ax(v) { xs.push(v) }
        function ay(v) { ys.push(v) }
        var list = nodes || []
        var i
        for (i = 0; i < list.length; i++) {
            var nn = list[i]
            if (dragKind && nn.id === selectedId)
                continue
            if (isDraw(nn)) {
                var g = drawGeom(nn)
                ax(g.x); ax(g.x + g.w); ax(g.x + g.w * 0.5)
                ay(g.y); ay(g.y + g.h); ay(g.y + g.h * 0.5)
                continue
            }
            var bb = chipBounds(nn)
            ax(bb.x); ax(bb.x + bb.w); ax(bb.x + bb.w * 0.5)
            ay(bb.y); ay(bb.y + bb.h); ay(bb.y + bb.h * 0.5)
            if (nn.nx !== undefined) {
                var hp = hotPt(nn)
                ax(hp.x)
                ay(hp.y)
            }
        }
        function nearest(v, arr) {
            var best = v
            var d = 8
            var j
            for (j = 0; j < arr.length; j++) {
                var dd = Math.abs(v - arr[j])
                if (dd < d) {
                    d = dd
                    best = arr[j]
                }
            }
            if (snapOn) {
                var g2 = snapPx(v)
                if (Math.abs(g2 - v) <= d)
                    best = g2
            }
            return best
        }
        return Qt.point(nearest(x, xs), nearest(y, ys))
    }

    function applyDrawResize(n, mx, my, handle, altOff) {
        if (!n)
            return
        n.around = []
        var p = snapEnt(mx, my, altOff)
        var x0 = rzX0
        var y0 = rzY0
        var x1 = rzX1
        var y1 = rzY1
        if (handle.indexOf("n") >= 0)
            y0 = p.y
        if (handle.indexOf("s") >= 0)
            y1 = p.y
        if (handle.indexOf("w") >= 0)
            x0 = p.x
        if (handle.indexOf("e") >= 0)
            x1 = p.x
        if (shiftHeld && handle.length === 2) {
            var fx0 = (handle.indexOf("w") >= 0) ? x1 : x0
            var fy0 = (handle.indexOf("n") >= 0) ? y1 : y0
            var mx1 = (handle.indexOf("w") >= 0) ? x0 : x1
            var my1 = (handle.indexOf("n") >= 0) ? y0 : y1
            var lp = lockAspect(fx0, fy0, mx1, my1)
            if (handle.indexOf("w") >= 0)
                x0 = lp.x
            else
                x1 = lp.x
            if (handle.indexOf("n") >= 0)
                y0 = lp.y
            else
                y1 = lp.y
        }
        var nx = Math.min(x0, x1)
        var ny = Math.min(y0, y1)
        var nw = Math.max(8, Math.abs(x1 - x0))
        var nh = Math.max(8, Math.abs(y1 - y0))
        n.fx = nx / Math.max(1, width)
        n.fy = ny / Math.max(1, height)
        n.fw = nw / Math.max(1, width)
        n.fh = nh / Math.max(1, height)
    }

    function _drawStyle() {
        return {
            kind: "draw",
            rot: 0,
            fill: "hollow",
            color: "#14532D",
            border: "#22C55E",
            stroke: 2,
            opacity: 1,
            pad: 8,
            around: []
        }
    }

    function addDrawAround(shape) {
        var ids = selectedIds || []
        var around = []
        var i
        for (i = 0; i < ids.length; i++) {
            var q = nodeAt(ids[i])
            if (q && !isDraw(q))
                around.push(ids[i])
        }
        if (!around.length)
            return
        var st = _drawStyle()
        st.id = _uid("d")
        st.shape = shape
        st.around = around
        var g = drawGeom(st)
        st.fx = g.x / Math.max(1, width)
        st.fy = g.y / Math.max(1, height)
        st.fw = g.w / Math.max(1, width)
        st.fh = g.h / Math.max(1, height)
        nodes.push(st)
        setSelection([st.id])
        bump()
    }

    function addDrawFree(shape, x0, y0, x1, y1) {
        if (shiftHeld) {
            var lp = lockAspect(x0, y0, x1, y1)
            x1 = lp.x
            y1 = lp.y
        }
        var x = Math.min(x0, x1)
        var y = Math.min(y0, y1)
        var w = Math.abs(x1 - x0)
        var h = Math.abs(y1 - y0)
        if (w < 6 || h < 6)
            return
        var st = _drawStyle()
        st.id = _uid("d")
        st.shape = shape
        st.fx = x / Math.max(1, width)
        st.fy = y / Math.max(1, height)
        st.fw = w / Math.max(1, width)
        st.fh = h / Math.max(1, height)
        nodes.push(st)
        setSelection([st.id])
        bump()
    }

    function setDrawTool(shape) {
        drawTool = (drawTool === shape) ? "" : shape
    }

    function lockAspect(x0, y0, x1, y1) {
        var w = x1 - x0
        var h = y1 - y0
        var s = Math.max(Math.abs(w), Math.abs(h))
        if (s < 1)
            s = 1
        return Qt.point(x0 + (w >= 0 ? s : -s), y0 + (h >= 0 ? s : -s))
    }

    function requestDrawColor(field) {
        var n = nodeAt(selectedId)
        if (!isDraw(n))
            return
        var hex = field === "border" ? (n.border || "#22C55E") : (n.color || "#14532D")
        colorPickRequested(field, hex)
    }

    function nudge(dx, dy) {
        var ids = (selectedIds && selectedIds.length) ? selectedIds.slice() : (selectedId ? [selectedId] : [])
        if (!ids.length)
            return
        var i
        for (i = 0; i < ids.length; i++) {
            var n = nodeAt(ids[i])
            if (!n)
                continue
            if (isDraw(n)) {
                var around = n.around || []
                if (around.length) {
                    var ai
                    for (ai = 0; ai < around.length; ai++) {
                        var qn = nodeAt(around[ai])
                        if (!qn || isDraw(qn))
                            continue
                        qn.chipFx = Math.max(0.01, Math.min(0.92, qn.chipFx + dx))
                        qn.chipFy = Math.max(0.01, Math.min(0.92, qn.chipFy + dy))
                    }
                } else {
                    n.fx = Math.max(0, Math.min(0.98, (n.fx || 0) + dx))
                    n.fy = Math.max(0, Math.min(0.98, (n.fy || 0) + dy))
                }
            } else {
                n.chipFx = Math.max(0.01, Math.min(0.92, (n.chipFx || 0) + dx))
                n.chipFy = Math.max(0.01, Math.min(0.92, (n.chipFy || 0) + dy))
            }
        }
        bump()
    }

    function _newId(n) {
        if (isDraw(n))
            return _uid("d")
        if (isGroup(n))
            return _uid("g")
        var k = n.kind || "btn"
        return _uid(k === "btn" ? "b" : k.charAt(0))
    }

    function shiftClone(n, dx, dy) {
        if (isDraw(n)) {
            n.fx = (n.fx || 0) + dx
            n.fy = (n.fy || 0) + dy
        } else {
            n.chipFx = Math.max(0.01, Math.min(0.92, (n.chipFx || 0) + dx))
            n.chipFy = Math.max(0.01, Math.min(0.92, (n.chipFy || 0) + dy))
            if (n.nx !== undefined)
                n.nx = Math.max(0, Math.min(1, n.nx + dx))
            if (n.ny !== undefined)
                n.ny = Math.max(0, Math.min(1, n.ny + dy))
        }
        var ls = n.leaders || []
        var li
        for (li = 0; li < ls.length; li++) {
            var sp = ls[li].spines || []
            var s
            for (s = 0; s < sp.length; s++) {
                sp[s].fx = (sp[s].fx || 0) + dx
                sp[s].fy = (sp[s].fy || 0) + dy
            }
            if (ls[li].from && ls[li].from.type === "free") {
                ls[li].from.fx = (ls[li].from.fx || 0) + dx
                ls[li].from.fy = (ls[li].from.fy || 0) + dy
            }
            if (ls[li].to && ls[li].to.type === "free") {
                ls[li].to.fx = (ls[li].to.fx || 0) + dx
                ls[li].to.fy = (ls[li].to.fy || 0) + dy
            }
        }
    }

    function pasteNodes(src, dx, dy) {
        if (!src || !src.length)
            return
        var map = {}
        var copies = []
        var i
        for (i = 0; i < src.length; i++) {
            var c = JSON.parse(JSON.stringify(src[i]))
            var old = c.id
            c.id = _newId(c)
            map[old] = c.id
            copies.push(c)
        }
        for (i = 0; i < copies.length; i++) {
            var n = copies[i]
            shiftClone(n, dx, dy)
            if (n.around && n.around.length) {
                var a = []
                var k
                for (k = 0; k < n.around.length; k++) {
                    if (map[n.around[k]])
                        a.push(map[n.around[k]])
                }
                n.around = a
            }
            var ls = n.leaders || []
            var li
            for (li = 0; li < ls.length; li++) {
                if (ls[li].from && ls[li].from.id && map[ls[li].from.id])
                    ls[li].from.id = map[ls[li].from.id]
                if (ls[li].to && ls[li].to.id && map[ls[li].to.id])
                    ls[li].to.id = map[ls[li].to.id]
            }
            nodes.push(n)
        }
        var ids = []
        for (i = 0; i < copies.length; i++)
            ids.push(copies[i].id)
        setSelection(ids)
        bump()
    }

    function duplicateSelection() {
        var ids = (selectedIds && selectedIds.length) ? selectedIds.slice() : (selectedId ? [selectedId] : [])
        var src = []
        var i
        for (i = 0; i < ids.length; i++) {
            var n = nodeAt(ids[i])
            if (n)
                src.push(n)
        }
        pasteNodes(src, 16 / Math.max(1, width), 16 / Math.max(1, height))
    }

    function copySelection() {
        var ids = (selectedIds && selectedIds.length) ? selectedIds.slice() : (selectedId ? [selectedId] : [])
        var arr = []
        var i
        for (i = 0; i < ids.length; i++) {
            var n = nodeAt(ids[i])
            if (n)
                arr.push(JSON.parse(JSON.stringify(n)))
        }
        clip = arr
    }

    function pasteClipboard() {
        pasteNodes(clip || [], 16 / Math.max(1, width), 16 / Math.max(1, height))
    }

    function bringForward() {
        var list = nodes || []
        var i
        for (i = list.length - 2; i >= 0; i--) {
            if (isSelected(list[i].id) && !isSelected(list[i + 1].id)) {
                var t = list[i]
                list[i] = list[i + 1]
                list[i + 1] = t
            }
        }
        bump()
    }

    function sendBack() {
        var list = nodes || []
        var i
        for (i = 1; i < list.length; i++) {
            if (isSelected(list[i].id) && !isSelected(list[i - 1].id)) {
                var t = list[i]
                list[i] = list[i - 1]
                list[i - 1] = t
            }
        }
        bump()
    }

    function hitDraw(n, mx, my) {
        var i = nodeIndex(n.id)
        var it = (i >= 0 && _chips) ? _chips.itemAt(i) : null
        if (!it)
            return ""
        var p = it.mapFromItem(_ed, mx, my)
        var w = it.width
        var h = it.height
        if (interactive && isSelected(n.id)) {
            var hs = [
                [0, 0, "nw"], [w, 0, "ne"], [0, h, "sw"], [w, h, "se"],
                [w * 0.5, 0, "n"], [w * 0.5, h, "s"], [0, h * 0.5, "w"], [w, h * 0.5, "e"]
            ]
            var t
            for (t = 0; t < hs.length; t++) {
                if (Math.hypot(p.x - hs[t][0], p.y - hs[t][1]) < 8)
                    return hs[t][2]
            }
        }
        if (p.x < 0 || p.y < 0 || p.x > w || p.y > h)
            return ""
        if (n.fill === "filled")
            return "body"
        var ring = Math.max(6, (n.stroke || 2) + 4)
        if (p.x <= ring || p.y <= ring || p.x >= w - ring || p.y >= h - ring)
            return "body"
        return ""
    }

    function paintDraw(ctx, n, w, h) {
        var stroke = n.stroke || 2
        var inset = stroke * 0.5 + 0.5
        var ww = Math.max(2, w - stroke)
        var hh = Math.max(2, h - stroke)
        var shape = n.shape || "rect"
        ctx.save()
        ctx.translate(inset, inset)
        ctx.beginPath()
        if (shape === "ellipse") {
            ctx.save()
            ctx.translate(ww * 0.5, hh * 0.5)
            ctx.scale(Math.max(0.5, ww * 0.5), Math.max(0.5, hh * 0.5))
            ctx.arc(0, 0, 1, 0, 6.2832)
            ctx.restore()
        } else if (shape === "triangle") {
            ctx.moveTo(ww * 0.5, 0)
            ctx.lineTo(ww, hh)
            ctx.lineTo(0, hh)
            ctx.closePath()
        } else if (shape === "diamond") {
            ctx.moveTo(ww * 0.5, 0)
            ctx.lineTo(ww, hh * 0.5)
            ctx.lineTo(ww * 0.5, hh)
            ctx.lineTo(0, hh * 0.5)
            ctx.closePath()
        } else if (shape === "roundrect") {
            var r = Math.min(14, ww * 0.2, hh * 0.2)
            ctx.moveTo(r, 0)
            ctx.lineTo(ww - r, 0)
            ctx.quadraticCurveTo(ww, 0, ww, r)
            ctx.lineTo(ww, hh - r)
            ctx.quadraticCurveTo(ww, hh, ww - r, hh)
            ctx.lineTo(r, hh)
            ctx.quadraticCurveTo(0, hh, 0, hh - r)
            ctx.lineTo(0, r)
            ctx.quadraticCurveTo(0, 0, r, 0)
            ctx.closePath()
        } else {
            ctx.rect(0, 0, ww, hh)
        }
        if (n.fill !== "hollow") {
            ctx.fillStyle = n.color || "#14532D"
            ctx.fill()
        }
        ctx.strokeStyle = n.border || "#22C55E"
        ctx.lineWidth = stroke
        ctx.stroke()
        ctx.restore()
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
        if (k === "plus" || k === "pair" || k === "axis_stack" || k === "stack")
            return true
        return !!(n.members && n.members.length)
    }

    function beginGroupEdit(id) {
        var n = nodeAt(id || selectedId)
        if (!isGroup(n))
            return
        ensureMemberOffsets(n)
        groupEditId = n.id
        selectedMember = 0
        setSelection([n.id])
        bump()
    }

    function endGroupEdit() {
        groupEditId = ""
        selectedMember = -1
        dragMember = -1
        if (dragKind === "member")
            dragKind = ""
        bump()
    }

    function ensureMemberOffsets(n) {
        var mem = n.members || []
        var i
        var any = false
        for (i = 0; i < mem.length; i++) {
            if (mem[i].ox !== undefined || mem[i].oy !== undefined) {
                any = true
                break
            }
        }
        if (any) {
            for (i = 0; i < mem.length; i++) {
                if (mem[i].ox === undefined) mem[i].ox = 0
                if (mem[i].oy === undefined) mem[i].oy = 0
            }
            return
        }
        // Default column. Do not keep a 5-way cross. ox/oy only used in free layout.
        var eh = Math.max(1, height)
        var pitch = stackPitch(n) / eh
        for (i = 0; i < mem.length; i++) {
            mem[i].ox = 0
            mem[i].oy = i * pitch
        }
    }

    function demoteSpecialKinds() {
        var list = nodes || []
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            if (!n)
                continue
            if (n.kind === "plus" || n.kind === "pair")
                n.kind = "stack"
        }
    }

    function chipWGuess(n, mem) {
        var fs = (n && n.fontSize) ? n.fontSize : 10
        var s = mem ? friendlyOf(n, mem) : friendlyOf(n, null)
        var pad = Math.max(10, ((n && n.chipSize) || 18) * 0.55)
        return String(s).length * fs * 0.50 + pad
    }

    function memberHit(n, mx, my) {
        if (!isGroup(n))
            return -1
        var mem = n.members || []
        for (var i = mem.length - 1; i >= 0; i--) {
            var x = n.chipFx * width + groupMinX(n) + memberLocalX(n, mem[i])
            var y = n.chipFy * height + groupMinY(n) + memberLocalY(n, mem[i])
            var h = chipH(n)
            var w = chipWGuess(n, mem[i])
            if (mx >= x && mx <= x + w && my >= y && my <= y + h)
                return i
        }
        return -1
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
                out.push({ hwId: mem[i].hwId, kind: leaf, role: mem[i].role || "", src: n, friendly: mem[i].friendly || "" })
        } else {
            out.push({ hwId: n.hwId, kind: n.kind || "btn", role: "", src: n, friendly: n.friendly || "" })
        }
        return out
    }

    function groupSelection() {
        var ids = selectedIds || []
        if (ids.length < 2)
            return
        var parts = []
        var i
        var n
        for (i = 0; i < ids.length; i++) {
            var chunkN = nodeAt(ids[i])
            if (_ed.isDraw(chunkN))
                continue
            var chunk = _partsFrom(chunkN)
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
        var ox0 = fx / c
        var oy0 = fy / c
        parts.sort(function(a, b) {
            var dy = (a.src.chipFy || 0) - (b.src.chipFy || 0)
            return dy !== 0 ? dy : ((a.src.chipFx || 0) - (b.src.chipFx || 0))
        })
        var members = []
        for (i = 0; i < parts.length; i++)
            members.push({
                hwId: parts[i].hwId,
                role: parts[i].role || ("m" + i),
                ox: parts[i].src.chipFx - ox0,
                oy: parts[i].src.chipFy - oy0,
                friendly: parts[i].friendly || parts[i].src.friendly || defaultFriendly(parts[i].kind, parts[i].hwId)
            })
        var g = {
            id: _uid("g"), kind: kind, members: members,
            nx: nx / c, ny: ny / c, chipFx: ox0, chipFy: oy0,
            pin: st.pin, spines: [], curve: st.curve, alignH: "left",
            color: st.color, border: st.border, textColor: st.textColor,
            highlight: st.highlight, hlColor: st.hlColor, hlBorder: st.hlBorder,
            hlText: st.hlText, fontSize: st.fontSize, label: "", chipSize: st.chipSize, chipShape: st.chipShape, chipFill: st.chipFill, hotSize: st.hotSize, hotShape: st.hotShape, hotFill: st.hotFill
        }
        g.from = { type: "chip", id: g.id, pin: g.pin }
        g.to = { type: "hot", id: g.id }
        g.leaders = [{
            id: g.id + "_L0",
            from: g.from,
            to: g.to,
            spines: [],
            curve: st.curve !== false
        }]
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
        var ew = Math.max(1, width)
        var eh = Math.max(1, height)
        for (i = 0; i < mem.length; i++) {
            var px = n.chipFx * ew + groupMinX(n) + memberLocalX(n, mem[i])
            var py = n.chipFy * eh + groupMinY(n) + memberLocalY(n, mem[i])
            created.push({
                id: _uid("b"), kind: leafKind, hwId: mem[i].hwId, prefix: prefix,
                label: "",
                friendly: mem[i].friendly || defaultFriendly(leafKind, mem[i].hwId),
                nx: n.nx, ny: n.ny,
                chipFx: Math.max(0.02, Math.min(0.9, px / ew)),
                chipFy: Math.max(0.02, Math.min(0.9, py / eh)),
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
        groupEditId = ""
        selectedMember = -1
        setSelection([])
        bump()
    }

    function setGroupKind(kind) {
        var n = nodeAt(selectedId)
        if (!isGroup(n) || !kind)
            return
        n.kind = kind === "plus" ? "stack" : kind
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
        function onWidthChanged() { _lines.requestPaint(); if (_grid) _grid.requestPaint() }
        function onHeightChanged() { _lines.requestPaint(); if (_grid) _grid.requestPaint() }
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
            x: {
                _ed.tick
                if (!node)
                    return 0
                if (_ed.isDraw(node))
                    return _ed.drawGeom(node).x
                var x = node.chipFx * _ed.width
                if (_ed.isGroup(node))
                    x += _ed.groupMinX(node)
                return x
            }
            y: {
                _ed.tick
                if (!node)
                    return 0
                if (_ed.isDraw(node))
                    return _ed.drawGeom(node).y
                var y = node.chipFy * _ed.height
                if (_ed.isGroup(node))
                    y += _ed.groupMinY(node)
                return y
            }
            z: { _ed.tick; return (_ed.isDraw(node) ? 2 : 3) }
            rotation: { _ed.tick; return (_ed.isDraw(node) && node.rot) ? node.rot : 0 }
            opacity: { _ed.tick; return (_ed.isDraw(node) && node.opacity !== undefined && node.opacity !== null) ? node.opacity : 1 }
            transformOrigin: Item.Center
            clip: false
            width: {
                _ed.tick
                if (!node)
                    return 40
                if (_ed.isDraw(node))
                    return _ed.drawGeom(node).w
                if (_ed.isGroup(node))
                    return _ed.groupSpanW(node)
                return (_body.item && _body.item.implicitWidth > 1) ? _body.item.implicitWidth : _ed.chipWGuess(node, null)
            }
            height: {
                _ed.tick
                if (!node)
                    return 20
                if (_ed.isDraw(node))
                    return _ed.drawGeom(node).h
                if (_ed.isGroup(node))
                    return _ed.groupSpanH(node)
                return (_body.item && _body.item.implicitHeight > 1) ? _body.item.implicitHeight : _ed.chipH(node)
            }

            Loader {
                id: _body
                clip: false
                width: {
                    _ed.tick
                    if (_wrap.node && (_ed.isGroup(_wrap.node) || _ed.isDraw(_wrap.node)))
                        return _wrap.width
                    return item ? item.implicitWidth : 0
                }
                height: {
                    _ed.tick
                    if (_wrap.node && (_ed.isGroup(_wrap.node) || _ed.isDraw(_wrap.node)))
                        return _wrap.height
                    return item ? item.implicitHeight : 0
                }
                sourceComponent: {
                    var n = _wrap.node
                    if (!n) return _tagComp
                    if (_ed.isDraw(n)) return _drawComp
                    return _ed.isGroup(n) ? _groupComp : _tagComp
                }
                onLoaded: {
                    item.node = Qt.binding(function() { return _wrap.node })
                    if (_wrap.node && _ed.isGroup(_wrap.node))
                        _ed.ensureMemberOffsets(_wrap.node)
                }
            }
        }
    }

    component SelRing: Rectangle {
        property bool on: false
        property color ringColor: "#FBBF24"
        anchors.fill: parent
        anchors.leftMargin: -4
        anchors.rightMargin: -4
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        z: -1
        antialiasing: true
        color: "transparent"
        border.width: 2
        border.color: on ? ringColor : "transparent"
        radius: parent.radius > 0 ? parent.radius + 4 : 0
    }

    Component {
        id: _groupComp
        Item {
            id: _grp
            property var node: ({ members: [] })
            Repeater {
                model: { _ed.tick; return (_grp.node && _grp.node.members) ? _grp.node.members.length : 0 }
                delegate: Loader {
                    required property int index
                    x: {
                        _ed.tick
                        var m = _grp.node && _grp.node.members ? _grp.node.members[index] : null
                        if (!m)
                            return 0
                        return _ed.memberLocalX(_grp.node, m)
                    }
                    y: {
                        _ed.tick
                        var m = _grp.node && _grp.node.members ? _grp.node.members[index] : null
                        if (!m)
                            return 0
                        return _ed.memberLocalY(_grp.node, m)
                    }
                    sourceComponent: _mini
                    onLoaded: {
                        item.node = Qt.binding(function() { return _grp.node })
                        item.memberIndex = index
                        item.hwId = Qt.binding(function() {
                            var m = _grp.node && _grp.node.members ? _grp.node.members[index] : null
                            return m && m.hwId ? m.hwId : 0
                        })
                        item.leafKind = Qt.binding(function() {
                            return (_grp.node && _grp.node.kind === "axis_stack") ? "axis" : "btn"
                        })
                    }
                }
            }
        }
    }

    Component {
        id: _drawComp
        Item {
            id: _drawRoot
            property var node: ({ kind: "draw" })
            anchors.fill: parent
            Canvas {
                id: _dc
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    if (node)
                        _ed.paintDraw(ctx, node, width, height)
                }
            }
            Connections {
                target: _ed
                function onTickChanged() { _dc.requestPaint() }
            }
            Repeater {
                model: (_ed.interactive && node && _ed.isSelected(node.id)) ? 8 : 0
                Rectangle {
                    required property int index
                    width: 8
                    height: 8
                    radius: 1
                    color: "#FBBF24"
                    border.color: "#18181B"
                    x: {
                        var xs = [0, _drawRoot.width, 0, _drawRoot.width, _drawRoot.width * 0.5, _drawRoot.width * 0.5, 0, _drawRoot.width]
                        return xs[index] - 4
                    }
                    y: {
                        var ys = [0, 0, _drawRoot.height, _drawRoot.height, 0, _drawRoot.height, _drawRoot.height * 0.5, _drawRoot.height * 0.5]
                        return ys[index] - 4
                    }
                    z: 4
                }
            }
        }
    }

    Component {
        id: _tagComp
        Rectangle {
            property var node: ({ kind: "btn", hwId: 0 })
            property bool on: _ed.litOf(node.kind, node.hwId)
            width: implicitWidth
            height: implicitHeight
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
                return on && node.highlight ? (node.hlBorder || "#22C55E") : (node.border || "#3F3F46")
            }
            border.width: { _ed.tick; return _ed.chipIsHollow(node) ? 2 : 1 }
            antialiasing: true
            SelRing {
                on: { _ed.tick; return _ed.isSelected(node.id) }
            }
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
                    return _ed.friendlyOf(node, null)
                }
            }
        }
    }

    Component {
        id: _mini
        Rectangle {
            property int hwId: 0
            property var node: ({})
            property int memberIndex: -1
            property string leafKind: "btn"
            property bool on: _ed.litOf(leafKind, hwId)
            width: implicitWidth
            height: implicitHeight
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
                return on && node.highlight ? (node.hlBorder || "#22C55E") : (node.border || "#3F3F46")
            }
            border.width: { _ed.tick; return _ed.chipIsHollow(node) ? 2 : 1 }
            antialiasing: true
            SelRing {
                on: {
                    _ed.tick
                    return _ed.isSelected(node.id)
                }
                ringColor: {
                    _ed.tick
                    if (_ed.groupEditId === node.id && _ed.selectedMember === memberIndex)
                        return "#38BDF8"
                    return "#FBBF24"
                }
            }
            Text {
                id: t
                anchors.centerIn: parent
                color: {
                    _ed.tick
                    return parent.on && node.highlight ? (node.hlText || "#BBF7D0") : (node.textColor || "#E4E4E7")
                }
                font.pixelSize: { _ed.tick; return node.fontSize || 10 }
                text: {
                    _ed.tick
                    var m = node && node.members ? node.members[memberIndex] : null
                    return _ed.friendlyOf(node, m)
                }
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
            _ed.demoteSpecialKinds()
            for (var i = 0; i < list.length; i++) {
                _ed.ensureFriendly(list[i])
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
                if (_ed.isDraw(n))
                    continue
                var sel = _ed.interactive && _ed.isSelected(n.id)
                var ls = _ed.leaderList(n)
                var li
                for (li = 0; li < ls.length; li++) {
                    var L = ls[li]
                    var leadSel = sel && _ed.selectedLeader === li
                    ctx.strokeStyle = leadSel ? "#FBBF24" : (sel ? "#D4D4D8" : "#A1A1AA")
                    ctx.lineWidth = leadSel ? 1.8 : 1.1
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    _ed.strokeLeader(ctx, n, _ed.pathPtsL(L), L)
                }
                var hot = _ed.hotPt(n)
                var hs = _ed.hotSz(n)
                var hShape = n.hotShape || "round"
                var hFill = n.hotFill || "filled"
                _ed.drawMark(ctx, hot.x, hot.y, hs, hShape, hFill, sel ? "#FBBF24" : "#F4F4F5")
                if (_ed.interactive) {
                    for (li = 0; li < ls.length; li++) {
                        var L2 = ls[li]
                        var leadSel2 = sel && _ed.selectedLeader === li
                        var a = _ed.endPt(L2.from)
                        _ed.drawMark(ctx, a.x, a.y, 8, "round", "filled", leadSel2 ? "#38BDF8" : "#64748B")
                        if (L2.to && L2.to.type !== "hot") {
                            var tp = _ed.endPt(L2.to)
                            _ed.drawMark(ctx, tp.x, tp.y, 8, "round", "filled", leadSel2 ? "#FB923C" : "#94A3B8")
                        }
                        var spines = L2.spines || []
                        for (var s = 0; s < spines.length; s++) {
                            var sx = spines[s].fx * width
                            var sy = spines[s].fy * height
                            ctx.beginPath()
                            ctx.arc(sx, sy, 5, 0, 6.3)
                            ctx.fillStyle = (leadSel2 && _ed.selectedSpine === s) ? "#F59E0B" : "#94A3B8"
                            ctx.fill()
                        }
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
        cursorShape: _ed.drawTool.length ? Qt.CrossCursor : Qt.ArrowCursor
        focus: true
        Keys.onDeletePressed: {
            var n = _ed.nodeAt(_ed.selectedId)
            if (_ed.isGroup(n))
                _ed.ungroupSelection()
            else
                _ed.deleteChip()
        }
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Backspace) {
                var n = _ed.nodeAt(_ed.selectedId)
                if (_ed.isGroup(n))
                    _ed.ungroupSelection()
                else
                    _ed.deleteChip()
                e.accepted = true
            } else if (e.key === Qt.Key_Escape) {
                _ed.endGroupEdit()
                _ed.drawTool = ""
                e.accepted = true
            } else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Z) {
                if (e.modifiers & Qt.ShiftModifier)
                    _ed.redo()
                else
                    _ed.undo()
                e.accepted = true
            } else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_D) {
                _ed.duplicateSelection()
                e.accepted = true
            } else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) {
                _ed.copySelection()
                e.accepted = true
            } else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) {
                _ed.pasteClipboard()
                e.accepted = true
            } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
                var step = (e.modifiers & Qt.ShiftModifier) ? Math.max(2, _ed.gridSize) : 1
                var dx = 0
                var dy = 0
                if (e.key === Qt.Key_Left) dx = -step
                if (e.key === Qt.Key_Right) dx = step
                if (e.key === Qt.Key_Up) dy = -step
                if (e.key === Qt.Key_Down) dy = step
                _ed.nudge(dx / Math.max(1, _ed.width), dy / Math.max(1, _ed.height))
                e.accepted = true
            }
        }

        onPressed: (m) => {
            forceActiveFocus()
            _ed.altHeld = !!(m.modifiers & Qt.AltModifier)
            _ed.shiftHeld = !!(m.modifiers & Qt.ShiftModifier)
            var hit = _ed.hitTest(m.x, m.y)
            var shift = (m.modifiers & Qt.ShiftModifier) || (m.modifiers & Qt.ControlModifier)
            if (m.button === Qt.RightButton) {
                if (hit.id) {
                    if (!shift && !_ed.isSelected(hit.id))
                        _ed.setSelection([hit.id])
                    _ctx.nodeId = hit.id
                    _ctx.seg = (hit.seg !== undefined) ? hit.seg : -1
                    _ctx.leader = (hit.leader !== undefined) ? hit.leader : 0
                    _ed.selectedLeader = _ctx.leader
                    _ed.selectedSeg = _ctx.seg
                    if (hit.kind === "spine")
                        _ed.selectedSpine = hit.spine
                    if (hit.kind === "member")
                        _ed.selectedMember = hit.member
                } else {
                    _ctx.nodeId = ""
                    _ctx.seg = -1
                    _ctx.leader = 0
                }
                _ed.chipMenuRequested(m.x, m.y)
                _ctx.popup()
                return
            }
            if (hit.kind === "draw") {
                if (shift)
                    _ed.toggleSelected(hit.id)
                else if (!_ed.isSelected(hit.id))
                    _ed.setSelection([hit.id])
                var dn = _ed.nodeAt(hit.id)
                var g = dn ? _ed.drawGeom(dn) : { x: 0, y: 0, w: 8, h: 8 }
                if (hit.handle && hit.handle !== "body") {
                    _ed.dragKind = "draw-" + hit.handle
                    _ed.rzX0 = g.x
                    _ed.rzY0 = g.y
                    _ed.rzX1 = g.x + g.w
                    _ed.rzY1 = g.y + g.h
                } else {
                    _ed.dragKind = "draw"
                    _ed.dragOffX = m.x - g.x
                    _ed.dragOffY = m.y - g.y
                }
                _ed.bump()
                return
            }
            if (_ed.drawTool.length && (!hit.kind || hit.kind === "")) {
                var p0 = _ed.snapEnt(m.x, m.y, _ed.altHeld)
                _ed.dragKind = "drawnew"
                _ed.drawX0 = p0.x
                _ed.drawY0 = p0.y
                _ed.drawX1 = p0.x
                _ed.drawY1 = p0.y
                return
            }
            if (hit.kind === "line" && !shift) {
                _ed.selectedId = hit.id
                _ed.selectedLeader = (hit.leader !== undefined) ? hit.leader : 0
                _ed.selectedSeg = (hit.seg !== undefined) ? hit.seg : 0
                _ed.addSpineAt(hit.id, m.x, m.y)
                return
            }
            if (hit.kind === "from" || hit.kind === "to") {
                if (!shift)
                    _ed.setSelection([hit.id])
                _ed.selectedId = hit.id
                _ed.selectedSpine = -1
                _ed.selectedLeader = (hit.leader !== undefined) ? hit.leader : 0
                _ed.dragKind = hit.kind
                var ne = _ed.nodeAt(hit.id)
                if (ne) {
                    var L0 = _ed.currentLeader(ne)
                    if (!L0)
                        return
                    var ep = _ed.endPt(hit.kind === "to" ? L0.to : L0.from)
                    var fr = { type: "free", fx: ep.x / Math.max(1, width), fy: ep.y / Math.max(1, height) }
                    if (hit.kind === "to") L0.to = fr
                    else L0.from = fr
                }
                _ed.bump()
                return
            }
            if (hit.kind === "member") {
                _ed.setSelection([hit.id])
                _ed.selectedId = hit.id
                _ed.selectedMember = hit.member
                _ed.selectedSpine = -1
                _ed.dragKind = "member"
                _ed.dragMember = hit.member
                var nm = _ed.nodeAt(hit.id)
                if (nm && nm.members && nm.members[hit.member]) {
                    var mm = nm.members[hit.member]
                    _ed.dragOffX = m.x - (nm.chipFx + (mm.ox || 0)) * width
                    _ed.dragOffY = m.y - (nm.chipFy + (mm.oy || 0)) * height
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
                _ed.selectedLeader = (hit.leader !== undefined) ? hit.leader : 0
                if (hit.kind === "spine")
                    _ed.selectedSeg = hit.spine + 1
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
            _ed.altHeld = !!(m.modifiers & Qt.AltModifier)
            _ed.shiftHeld = !!(m.modifiers & Qt.ShiftModifier)
            if (!_ed.dragKind) {
                return
            }
            if (_ed.dragKind === "drawnew") {
                var p1 = _ed.snapEnt(m.x, m.y, _ed.altHeld)
                if (_ed.shiftHeld) {
                    var lp = _ed.lockAspect(_ed.drawX0, _ed.drawY0, p1.x, p1.y)
                    p1 = lp
                }
                _ed.drawX1 = p1.x
                _ed.drawY1 = p1.y
                return
            }
            if (_ed.dragKind === "band") {
                _ed.bandX1 = m.x
                _ed.bandY1 = m.y
                if (!_ed.banding && Math.hypot(m.x - _ed.bandX0, m.y - _ed.bandY0) > 4)
                    _ed.banding = true
                return
            }
            _ed.applyPointer(m.x, m.y, _ed.altHeld)
        }
        onReleased: (m) => {
            if (_ed.dragKind === "drawnew") {
                _ed.addDrawFree(_ed.drawTool, _ed.drawX0, _ed.drawY0, _ed.drawX1, _ed.drawY1)
                _ed.dragKind = ""
                return
            }
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
                    var Lr = _ed.currentLeader(n3)
                    if (Lr) {
                        if (_ed.dragKind === "to") Lr.to = hooked
                        else {
                            Lr.from = hooked
                            if (hooked.type === "chip" && hooked.id === n3.id)
                                n3.pin = hooked.pin || n3.pin
                        }
                        if (_ed.selectedLeader === 0) {
                            n3.to = Lr.to
                            n3.from = Lr.from
                        }
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
            if (hit.kind === "line") {
                _ed.selectedId = hit.id
                _ed.selectedLeader = (hit.leader !== undefined) ? hit.leader : 0
                _ed.selectedSeg = (hit.seg !== undefined) ? hit.seg : 0
                _ed.toggleSegCurve()
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
        text: _ed.drawTool.length ? ("Draw " + _ed.drawTool + " — drag on empty. Esc cancels.") : "Right-click Chip / Draw / Group / Leader. Esc cancels draw tool and group edit."
    }

    Canvas {
        visible: _ed.interactive && _ed.dragKind === "drawnew"
        x: Math.min(_ed.drawX0, _ed.drawX1)
        y: Math.min(_ed.drawY0, _ed.drawY1)
        width: Math.max(1, Math.abs(_ed.drawX1 - _ed.drawX0))
        height: Math.max(1, Math.abs(_ed.drawY1 - _ed.drawY0))
        z: 7
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            _ed.paintDraw(ctx, { shape: _ed.drawTool || "rect", fill: "hollow", color: "#14532D", border: "#22C55E", stroke: 2 }, width, height)
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Menu {
        id: _ctx
        property string nodeId: ""
        property int seg: -1
        property int leader: 0
        MenuItem {
            text: "Undo"
            enabled: _ed.canUndo
            onTriggered: _ed.undo()
        }
        MenuItem {
            text: "Redo"
            enabled: _ed.canRedo
            onTriggered: _ed.redo()
        }
        MenuSeparator {}
        Menu {
            title: "Chip"
            enabled: _ed.selectedId !== "" && !_ed.isDraw(_ed.nodeAt(_ed.selectedId))
            MenuItem {
                enabled: false
                text: {
                    var n = _ed.nodeAt(_ed.selectedId)
                    return n ? (n.friendly || n.id || "Chip") : "Chip"
                }
            }
            MenuSeparator {}
            Menu {
                id: _fontMenu
                title: "Font size"
                Instantiator {
                    model: [8, 9, 10, 11, 12, 14, 16, 18, 20, 22]
                    delegate: MenuItem {
                        required property int modelData
                        text: "" + modelData
                        checkable: true
                        checked: _ed.fieldEq("fontSize", modelData, 10)
                        onTriggered: _ed.applyField("fontSize", modelData)
                    }
                    onObjectAdded: (i, obj) => _fontMenu.insertItem(i, obj)
                    onObjectRemoved: (i, obj) => _fontMenu.removeItem(obj)
                }
            }
            Menu {
                title: "Chip"
                Menu {
                    id: _chipSzMenu
                    title: "Size"
                    Instantiator {
                        model: [12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 42, 48]
                        delegate: MenuItem {
                            required property int modelData
                            text: "" + modelData
                            checkable: true
                            checked: _ed.fieldEq("chipSize", modelData, 18)
                            onTriggered: _ed.applyField("chipSize", modelData)
                        }
                        onObjectAdded: (i, obj) => _chipSzMenu.insertItem(i, obj)
                        onObjectRemoved: (i, obj) => _chipSzMenu.removeItem(obj)
                    }
                }
                MenuItem {
                    text: "Round"
                    checkable: true
                    checked: _ed.fieldEq("chipShape", "round", "round")
                    onTriggered: _ed.applyField("chipShape", "round")
                }
                MenuItem {
                    text: "Square"
                    checkable: true
                    checked: _ed.fieldEq("chipShape", "square", "round")
                    onTriggered: _ed.applyField("chipShape", "square")
                }
                MenuSeparator {}
                MenuItem {
                    text: "Filled"
                    checkable: true
                    checked: _ed.fieldEq("chipFill", "filled", "filled")
                    onTriggered: _ed.applyField("chipFill", "filled")
                }
                MenuItem {
                    text: "Hollow"
                    checkable: true
                    checked: _ed.fieldEq("chipFill", "hollow", "filled")
                    onTriggered: _ed.applyField("chipFill", "hollow")
                }
            }
            Menu {
                title: "Hotspot"
                Menu {
                    id: _hotSzMenu
                    title: "Size"
                    Instantiator {
                        model: [4, 6, 8, 9, 10, 12, 14, 16, 20, 24, 28]
                        delegate: MenuItem {
                            required property int modelData
                            text: "" + modelData
                            checkable: true
                            checked: _ed.fieldEq("hotSize", modelData, 9)
                            onTriggered: _ed.applyField("hotSize", modelData)
                        }
                        onObjectAdded: (i, obj) => _hotSzMenu.insertItem(i, obj)
                        onObjectRemoved: (i, obj) => _hotSzMenu.removeItem(obj)
                    }
                }
                MenuItem {
                    text: "Round"
                    checkable: true
                    checked: _ed.fieldEq("hotShape", "round", "round")
                    onTriggered: _ed.applyField("hotShape", "round")
                }
                MenuItem {
                    text: "Square"
                    checkable: true
                    checked: _ed.fieldEq("hotShape", "square", "round")
                    onTriggered: _ed.applyField("hotShape", "square")
                }
                MenuSeparator {}
                MenuItem {
                    text: "Filled"
                    checkable: true
                    checked: _ed.fieldEq("hotFill", "filled", "filled")
                    onTriggered: _ed.applyField("hotFill", "filled")
                }
                MenuItem {
                    text: "Hollow"
                    checkable: true
                    checked: _ed.fieldEq("hotFill", "hollow", "filled")
                    onTriggered: _ed.applyField("hotFill", "hollow")
                }
            }
            MenuItem {
                text: "Highlight on press"
                checkable: true
                checked: {
                    var n = _ed.nodeAt(_ed.selectedId)
                    return !n || n.highlight !== false
                }
                onTriggered: {
                    var n = _ed.nodeAt(_ed.selectedId)
                    _ed.applyField("highlight", !(n && n.highlight !== false))
                }
            }
            MenuSeparator {}
            MenuItem {
                text: "Delete chip"
                enabled: {
                    var n = _ed.nodeAt(_ed.selectedId)
                    return !!n && !_ed.isGroup(n) && !_ed.isDraw(n)
                }
                onTriggered: _ed.deleteChip()
            }
        }
        Menu {
            title: "Draw"
            Menu {
                title: "Around selection"
                enabled: {
                    var ids = _ed.selectedIds || []
                    var k
                    for (k = 0; k < ids.length; k++) {
                        if (!_ed.isDraw(_ed.nodeAt(ids[k])))
                            return true
                    }
                    return false
                }
                MenuItem { text: "Rectangle"; onTriggered: _ed.addDrawAround("rect") }
                MenuItem { text: "Rounded"; onTriggered: _ed.addDrawAround("roundrect") }
                MenuItem { text: "Ellipse"; onTriggered: _ed.addDrawAround("ellipse") }
                MenuItem { text: "Triangle"; onTriggered: _ed.addDrawAround("triangle") }
                MenuItem { text: "Diamond"; onTriggered: _ed.addDrawAround("diamond") }
            }
            Menu {
                title: "Free drag"
                MenuItem { text: "Rectangle"; checkable: true; checked: _ed.drawTool === "rect"; onTriggered: _ed.setDrawTool("rect") }
                MenuItem { text: "Rounded"; checkable: true; checked: _ed.drawTool === "roundrect"; onTriggered: _ed.setDrawTool("roundrect") }
                MenuItem { text: "Ellipse"; checkable: true; checked: _ed.drawTool === "ellipse"; onTriggered: _ed.setDrawTool("ellipse") }
                MenuItem { text: "Triangle"; checkable: true; checked: _ed.drawTool === "triangle"; onTriggered: _ed.setDrawTool("triangle") }
                MenuItem { text: "Diamond"; checkable: true; checked: _ed.drawTool === "diamond"; onTriggered: _ed.setDrawTool("diamond") }
                MenuSeparator {}
                MenuItem { text: "Cancel tool"; enabled: _ed.drawTool.length > 0; onTriggered: _ed.drawTool = "" }
            }
            MenuSeparator {}
            Menu {
                title: "Shape"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                MenuItem { text: "Rectangle"; checkable: true; checked: _ed.fieldEq("shape", "rect", "rect"); onTriggered: _ed.applyField("shape", "rect") }
                MenuItem { text: "Rounded"; checkable: true; checked: _ed.fieldEq("shape", "roundrect", "rect"); onTriggered: _ed.applyField("shape", "roundrect") }
                MenuItem { text: "Ellipse"; checkable: true; checked: _ed.fieldEq("shape", "ellipse", "rect"); onTriggered: _ed.applyField("shape", "ellipse") }
                MenuItem { text: "Triangle"; checkable: true; checked: _ed.fieldEq("shape", "triangle", "rect"); onTriggered: _ed.applyField("shape", "triangle") }
                MenuItem { text: "Diamond"; checkable: true; checked: _ed.fieldEq("shape", "diamond", "rect"); onTriggered: _ed.applyField("shape", "diamond") }
            }
            Menu {
                id: _padMenu
                title: "Padding"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                Instantiator {
                    model: [4, 8, 12, 16, 24, 32]
                    delegate: MenuItem {
                        required property int modelData
                        text: "" + modelData
                        checkable: true
                        checked: _ed.fieldEq("pad", modelData, 8)
                        onTriggered: _ed.applyField("pad", modelData)
                    }
                    onObjectAdded: (i, obj) => _padMenu.insertItem(i, obj)
                    onObjectRemoved: (i, obj) => _padMenu.removeItem(obj)
                }
            }
            Menu {
                title: "Rotate"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                MenuItem { text: "0°"; onTriggered: _ed.applyField("rot", 0) }
                MenuItem { text: "90°"; onTriggered: _ed.applyField("rot", 90) }
                MenuItem { text: "180°"; onTriggered: _ed.applyField("rot", 180) }
                MenuItem { text: "270°"; onTriggered: _ed.applyField("rot", 270) }
                MenuItem { text: "-15°"; onTriggered: { var n = _ed.nodeAt(_ed.selectedId); _ed.applyField("rot", ((n && n.rot) ? n.rot : 0) - 15) } }
                MenuItem { text: "+15°"; onTriggered: { var n = _ed.nodeAt(_ed.selectedId); _ed.applyField("rot", ((n && n.rot) ? n.rot : 0) + 15) } }
            }
            MenuItem {
                text: "Filled"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                checkable: true
                checked: _ed.fieldEq("fill", "filled", "hollow")
                onTriggered: _ed.applyField("fill", "filled")
            }
            MenuItem {
                text: "Hollow"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                checkable: true
                checked: _ed.fieldEq("fill", "hollow", "hollow")
                onTriggered: _ed.applyField("fill", "hollow")
            }
            MenuItem {
                text: "Fill color…"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                onTriggered: _ed.requestDrawColor("color")
            }
            MenuItem {
                text: "Stroke color…"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                onTriggered: _ed.requestDrawColor("border")
            }
            Menu {
                title: "Stroke"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                MenuItem { text: "1"; checkable: true; checked: _ed.fieldEq("stroke", 1, 2); onTriggered: _ed.applyField("stroke", 1) }
                MenuItem { text: "2"; checkable: true; checked: _ed.fieldEq("stroke", 2, 2); onTriggered: _ed.applyField("stroke", 2) }
                MenuItem { text: "3"; checkable: true; checked: _ed.fieldEq("stroke", 3, 2); onTriggered: _ed.applyField("stroke", 3) }
                MenuItem { text: "4"; checkable: true; checked: _ed.fieldEq("stroke", 4, 2); onTriggered: _ed.applyField("stroke", 4) }
                MenuItem { text: "6"; checkable: true; checked: _ed.fieldEq("stroke", 6, 2); onTriggered: _ed.applyField("stroke", 6) }
            }
            Menu {
                title: "Opacity"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                MenuItem { text: "25%"; checkable: true; checked: _ed.fieldEq("opacity", 0.25, 1); onTriggered: _ed.applyField("opacity", 0.25) }
                MenuItem { text: "50%"; checkable: true; checked: _ed.fieldEq("opacity", 0.5, 1); onTriggered: _ed.applyField("opacity", 0.5) }
                MenuItem { text: "75%"; checkable: true; checked: _ed.fieldEq("opacity", 0.75, 1); onTriggered: _ed.applyField("opacity", 0.75) }
                MenuItem { text: "100%"; checkable: true; checked: _ed.fieldEq("opacity", 1, 1); onTriggered: _ed.applyField("opacity", 1) }
            }
            MenuSeparator {}
            MenuItem {
                text: "Bring forward"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                onTriggered: _ed.bringForward()
            }
            MenuItem {
                text: "Send back"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                onTriggered: _ed.sendBack()
            }
            MenuItem {
                text: "Detach from chips"
                enabled: {
                    var n = _ed.nodeAt(_ed.selectedId)
                    return _ed.isDraw(n) && n.around && n.around.length
                }
                onTriggered: {
                    var n = _ed.nodeAt(_ed.selectedId)
                    if (!n) return
                    var g = _ed.drawGeom(n)
                    n.around = []
                    n.fx = g.x / Math.max(1, _ed.width)
                    n.fy = g.y / Math.max(1, _ed.height)
                    n.fw = g.w / Math.max(1, _ed.width)
                    n.fh = g.h / Math.max(1, _ed.height)
                    _ed.bump()
                }
            }
            MenuItem {
                text: "Delete drawing"
                enabled: _ed.isDraw(_ed.nodeAt(_ed.selectedId))
                onTriggered: _ed.deleteChip()
            }
        }


        Menu {
            title: "Group"
            MenuItem {
                text: "Group selected"
                enabled: _ed.canGroup()
                onTriggered: _ed.groupSelection()
            }
            MenuItem {
                text: "Break group"
                enabled: _ed.isGroup(_ed.nodeAt(_ctx.nodeId))
                onTriggered: {
                    _ed.setSelection([_ctx.nodeId])
                    _ed.ungroupSelection()
                }
            }
            MenuItem {
                text: "Edit group"
                enabled: _ed.isGroup(_ed.nodeAt(_ctx.nodeId))
                onTriggered: _ed.beginGroupEdit(_ctx.nodeId)
            }
            MenuItem {
                text: "Done editing group"
                enabled: _ed.groupEditId !== ""
                onTriggered: _ed.endGroupEdit()
            }
            MenuSeparator {}
            MenuItem { text: "Align left"; onTriggered: _ed.setAlignH("left") }
            MenuItem { text: "Align center"; onTriggered: _ed.setAlignH("center") }
            MenuItem { text: "Align right"; onTriggered: _ed.setAlignH("right") }
            MenuItem { text: "Free layout"; onTriggered: _ed.setAlignH("free") }
        }
        Menu {
            title: "Leader"
            MenuItem { text: "Add straight spine"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.ensureMidSpine(_ed.nodeAt(_ed.selectedId)); _ed.bump() } }
            MenuItem { text: "Add curved spine"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.addCurveSpine(_ed.nodeAt(_ed.selectedId)) } }
            Menu {
                title: "This segment"
                MenuItem { text: "Curved"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.selectedLeader = _ctx.leader; _ed.selectedSeg = _ctx.seg; _ed.setSegCurve(_ed.currentLeader(_ed.nodeAt(_ed.selectedId)), Math.max(0, _ctx.seg), true) } }
                MenuItem { text: "Straight"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.selectedLeader = _ctx.leader; _ed.selectedSeg = _ctx.seg; _ed.setSegCurve(_ed.currentLeader(_ed.nodeAt(_ed.selectedId)), Math.max(0, _ctx.seg), false) } }
            }
            Menu {
                title: "All segments"
                MenuItem { text: "Curved"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.setAllSegCurve(true) } }
                MenuItem { text: "Straight"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.setAllSegCurve(false) } }
            }
            MenuSeparator {}
            MenuItem { text: "Add leader"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.addLeader() } }
            MenuItem { text: "Branch from this end"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.selectedLeader = _ctx.leader; _ed.addBranch() } }
            Menu {
                title: "Attach"
                MenuItem { text: "Detach chip end"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.detachEnd("from") } }
                MenuItem { text: "Detach hotspot end"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.detachEnd("to") } }
                MenuItem { text: "Reconnect to this chip"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.attachEndToSelf("from") } }
                MenuItem { text: "Reconnect to this hotspot"; onTriggered: { _ed.selectedId = _ctx.nodeId || _ed.selectedId; _ed.attachEndToSelf("to") } }
            }
            MenuSeparator {}
            MenuItem {
                text: "Delete spine"
                enabled: _ed.selectedSpine >= 0
                onTriggered: {
                    _ed.selectedId = _ctx.nodeId || _ed.selectedId
                    _ed.selectedLeader = _ctx.leader
                    _ed.deleteSelection()
                }
            }
            MenuItem {
                text: "Delete leader"
                onTriggered: {
                    _ed.selectedId = _ctx.nodeId || _ed.selectedId
                    _ed.selectedLeader = _ctx.leader
                    _ed.deleteLeader()
                }
            }
        }
    }
}
