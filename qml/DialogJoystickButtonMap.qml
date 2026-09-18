// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Window {
    id: _buttonMap

    width: 1180
    height: 980
    minimumWidth: 880
    minimumHeight: 720

    color: Style.background
    Universal.theme: Style.theme

    title: "Joystick Button Map — VKBsim Gladiator EVO R"

    onClosing: (e) => {
        if (_allowClose || !editing)
            return
        if (!isDirty())
            return
        e.accepted = false
        _leaveDlg.kind = "close"
        _leaveDlg.open()
    }

    readonly property string targetName: "VKBsim Gladiator EVO R"
    readonly property string stockImage: "qml/images/vkb_gladiator_rig.jpg"
    property int _nameTick: 0
    property bool editing: false
    onEditingChanged: {
        poolDrag = false
        if (editing)
            Qt.callLater(refreshReservoir)
    }
    property var liveNodes
    property var workNodes
    property string photoOverride: ""
    property string storedImage: ""
    property string liveImage: ""
    property string selectedId: ""
    property var selectedNode: null
    property bool _allowClose: false
    property var resItems
    property int resTick: 0
    property string poolFilter: ""
    onPoolFilterChanged: refreshReservoir()
    property bool poolDrag: false
    property string poolKind: "btn"
    property int poolHw: 0
    property string poolName: ""
    property real poolX: 0
    property real poolY: 0
    property int chipPopW: 280
    property int chipPopH: 480
    property bool gridOn: true
    property bool snapOn: true
    property bool snapEntOn: true
    property int gridSize: 8
    property bool chipPopPlaced: false
    property real panelW: 0
    property real panelH: 160
    property bool panelFillW: true
    property bool panelDockB: true
    property real _prsX: 0
    property real _prsY: 0
    property real _prsW: 0
    property real _prsH: 0
    property real _prmX: 0
    property real _prmY: 0
    property string _prEdge: ""
    property bool saveOk: true

    function clampPool() {
        var box = _poolFloat
        if (!box || !box.parent)
            return
        var pw = box.parent.width
        var ph = box.parent.height
        if (panelFillW || box.width < 40) {
            box.x = 12
            box.width = Math.max(280, pw - 24)
        }
        box.width = Math.max(280, Math.min(box.width, pw - 16))
        box.height = Math.max(90, Math.min(panelH, ph - 16))
        panelH = box.height
        if (panelDockB)
            box.y = ph - box.height - 12
        box.x = Math.max(8, Math.min(box.x, pw - box.width - 8))
        box.y = Math.max(8, Math.min(box.y, ph - box.height - 8))
    }

    function startPanelResize(edge, mx, my, item) {
        _prEdge = edge
        _prsX = _poolFloat.x
        _prsY = _poolFloat.y
        _prsW = _poolFloat.width
        _prsH = _poolFloat.height
        var p = item.mapToItem(_poolFloat.parent, mx, my)
        _prmX = p.x
        _prmY = p.y
    }

    function movePanelResize(mx, my, item) {
        var p = item.mapToItem(_poolFloat.parent, mx, my)
        var dx = p.x - _prmX
        var dy = p.y - _prmY
        var nx = _prsX
        var ny = _prsY
        var nw = _prsW
        var nh = _prsH
        var e = _prEdge
        var host = _poolFloat.parent
        if (e.indexOf("e") >= 0) {
            nw = _prsW + dx
            panelFillW = false
        }
        if (e.indexOf("w") >= 0) {
            nw = _prsW - dx
            panelFillW = false
        }
        if (e.indexOf("s") >= 0) {
            nh = _prsH + dy
            panelDockB = false
        }
        if (e.indexOf("n") >= 0)
            nh = _prsH - dy
        var maxW = Math.max(280, host.width - 16)
        var maxH = Math.max(90, host.height - 16)
        nw = Math.max(280, Math.min(nw, maxW))
        nh = Math.max(90, Math.min(nh, maxH))
        if (e.indexOf("w") >= 0)
            nx = _prsX + _prsW - nw
        if (e.indexOf("n") >= 0)
            ny = _prsY + _prsH - nh
        nx = Math.max(8, Math.min(nx, host.width - nw - 8))
        ny = Math.max(8, Math.min(ny, host.height - nh - 8))
        _poolFloat.x = nx
        _poolFloat.y = ny
        _poolFloat.width = nw
        _poolFloat.height = nh
        panelH = nh
        panelW = nw
    }

    ViewerDeviceModel { id: _devices }
    HardwareProfile { id: _hw }

    DeviceNames {
        id: _names
        onChanged: _buttonMap._nameTick++
    }

    function displayName(guid, name) {
        if (!_names) {
            return name
        }
        return _nameTick, _names.display(guid, name)
    }

    function isTarget(guid, name) {
        var raw = String(name || "")
        var shown = String(displayName(guid, raw) || "")
        if (raw === targetName || shown === targetName) {
            return true
        }
        var a = raw.toLowerCase()
        var b = shown.toLowerCase()
        if (a.indexOf("evo l") !== -1 || b.indexOf("evo l") !== -1) {
            return false
        }
        if (a.indexOf("ot l") !== -1 || b.indexOf("ot l") !== -1) {
            return false
        }
        function isRight(s) {
            return s.indexOf("gladiator") !== -1 && (s.indexOf("evo r") !== -1 || s.indexOf("ot r") !== -1)
        }
        return isRight(a) || isRight(b)
    }

    function parseDoc(text) {
        try {
            var d = JSON.parse(text)
            return (d && d.nodes) ? d : null
        } catch (e) {
            return null
        }
    }

    function hydrateOverlays(list) {
        if (!list)
            return
        var i
        for (i = 0; i < list.length; i++) {
            var n = list[i]
            if (n && n.shape === "image" && n.src)
                n.srcUrl = _hw.imageUrl(n.src)
        }
    }

    function applyImage(rel) {
        storedImage = rel && rel.length ? rel : stockImage
        photoOverride = _hw.imageUrl(storedImage)
    }

    function loadLive() {
        var text = _hw.load(targetName)
        var doc = parseDoc(text)
        if (!doc || !doc.nodes) {
            return false
        }
        liveNodes = JSON.parse(JSON.stringify(doc.nodes))
        hydrateOverlays(liveNodes)
        liveImage = doc.image && doc.image.length ? doc.image : stockImage
        if (doc.ui)
            applyUi(doc.ui)
        applyImage(liveImage)
        applyGridToEditor()
        return true
    }

    function enterEdit() {
        if (editing)
            return
        try {
            loadLive()
        } catch (e) {
            console.warn("Button Map loadLive failed", e)
        }
        var src = []
        try {
            src = JSON.parse(JSON.stringify(liveNodes || []))
        } catch (e2) {
            console.warn("Button Map clone nodes failed", e2)
            src = []
        }
        workNodes = src
        hydrateOverlays(workNodes)
        applyImage(liveImage.length ? liveImage : stockImage)
        editing = true
        selectedId = ""
        selectedNode = null
        Qt.callLater(function() {
            refreshReservoir()
            clampPool()
            applyGridToEditor()
            hydrateOverlays((_ed() && _ed().nodes) ? _ed().nodes : workNodes)
        })
    }

    function saveEdit() {
        var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
        var nodes = []
        if (ed && ed.nodes)
            nodes = ed.nodes
        else if (workNodes)
            nodes = workNodes
        var image = storedImage.length ? storedImage : stockImage
        var doc = {
            kind: "control.hardware",
            device: targetName,
            image: image,
            imageWidth: 899,
            imageHeight: 920,
            ui: uiBag(),
            nodes: nodes
        }
        var payload = JSON.stringify(doc)
        if (!_hw.save(targetName, payload)) {
            saveOk = false
            _savedPop.open()
            return
        }
        var check = parseDoc(_hw.load(targetName))
        if (!check || !check.nodes) {
            saveOk = false
            _savedPop.open()
            return
        }
        liveNodes = JSON.parse(JSON.stringify(nodes))
        liveImage = image
        applyImage(liveImage)
        hydrateOverlays(liveNodes)
        saveOk = true
        _savedPop.open()
    }

    function editorNodesNow() {
        var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
        if (ed && ed.nodes && ed.nodes.length)
            return ed.nodes
        return workNodes
    }

    function isDirty() {
        if (!editing)
            return false
        var image = storedImage.length ? storedImage : stockImage
        var live = liveImage.length ? liveImage : stockImage
        try {
            return JSON.stringify({ image: image, nodes: editorNodesNow() }) !== JSON.stringify({ image: live, nodes: liveNodes })
        } catch (e) {
            return true
        }
    }

    function discardEdit() {
        editing = false
        workNodes = []
        selectedId = ""
        selectedNode = null
        applyImage(liveImage)
    }

    function cancelEdit() {
        if (isDirty()) {
            _leaveDlg.kind = "cancel"
            _leaveDlg.open()
            return
        }
        discardEdit()
    }

    function confirmLeaveSave() {
        saveEdit()
        _leaveDlg.close()
        if (!editing && _leaveDlg.kind === "close") {
            _allowClose = true
            close()
        }
    }

    function confirmLeaveDiscard() {
        discardEdit()
        _leaveDlg.close()
        if (_leaveDlg.kind === "close") {
            _allowClose = true
            close()
        }
    }

    function currentNode() {
        var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
        if (ed && ed.selectedId) {
            return ed.nodeAt(ed.selectedId)
        }
        return null
    }

    function openColorField(field, hex, anchorItem) {
        if (!_colorPop)
            return
        _colorPop.openField(field, hex, anchorItem)
    }

    function applySelected() {
        var n = currentNode()
        selectedNode = n
        selectedId = n ? n.id : ""
    }

    Component.onCompleted: {
        liveNodes = []
        workNodes = []
        resItems = []
        if (_devices) {
            _devices.reload()
        }
        if (!loadLive()) {
            liveImage = stockImage
            storedImage = stockImage
        }
    }

    Dialog {
        id: _leaveDlg
        property string kind: "cancel"
        title: "Unsaved changes"
        modal: true
        anchors.centerIn: parent
        width: 440
        standardButtons: Dialog.NoButton
        closePolicy: Popup.CloseOnEscape

        ColumnLayout {
            anchors.fill: parent
            spacing: 12
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#FBBF24"
                text: "Caution: you have unsaved editor changes. If you leave without Save, this work will be lost."
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#A1A1AA"
                text: "Save writes the control.hardware profile and the live map. Discard restores the last saved map."
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button {
                    text: "Stay"
                    onClicked: _leaveDlg.close()
                }
                Button {
                    text: "Discard"
                    onClicked: _buttonMap.confirmLeaveDiscard()
                }
                Button {
                    text: "Save"
                    highlighted: true
                    onClicked: _buttonMap.confirmLeaveSave()
                }
            }
        }

        onRejected: close()
    }

    Dialog {
        id: _helpDlg
        title: "Button Map Editor — Help"
        modal: true
        anchors.centerIn: parent
        width: 640
        height: 680
        standardButtons: Dialog.Close
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        ListView {
            id: _helpList
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 14
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            model: [
                {
                    h: "Overview",
                    b: "Button Map is a photo of the VKBsim Gladiator EVO R with chips on the hardware contacts. File → Edit Mapping starts a session. The live window uses the same layout; pressing the stick still lights the matching chip. Layout does not change bindings.\n\nFile → Save writes control.hardware (qml/maps/vkb_evo_r.json) and becomes the live map. File → Cancel drops the session. Closing with unsaved work asks first.\nF1 or Help → Editor help opens this page."
                },
                {
                    h: "File",
                    b: "Edit Mapping — start the editor.\nSave — write the profile and live map. The editor stays open. After a verified write, Mapping saved appears; click outside it or Esc to dismiss. If the write or re-read fails, a red Save failed warning appears. Click OK to dismiss it — clicking outside does not close it.\nCancel — leave without writing.\nReset layout — send every chip back to the reservoir. Inputs still illuminate.\nChoose background… — pick a photo under the map.\nImport overlay… — add a PNG/JPEG plate (5-way plus, etc.) on top of the photo. Transform, lock, plant snap points, drop chips onto them.\nClear image — restore the stock rig photo.\nExit — close the window. Unsaved work still warns."
                },
                {
                    h: "Edit menu",
                    b: "Undo / Redo — layout history for this session (also Ctrl+Z / Ctrl+Y).\nDuplicate (Ctrl+D) — copy the selection offset so it does not stack.\nCopy / Paste (Ctrl+C / Ctrl+V) — clipboard of chips, groups, and frames."
                },
                {
                    h: "View, zoom, pan",
                    b: "Scroll wheel zooms about 50%–400%. Middle-button drag pans. View → Reset view returns 100% and centered.\nA resize or photo reload keeps a valid zoom. It only recenters when zoom or pan is broken (NaN or out of range).\nView → Grid → Show grid — overlay. Saved with the map.\nSnap to grid — drag onto grid points. Size 4 / 8 / 16 / 32.\nSnap to entities — snap to other chips, hots, frames.\nAlt while dragging skips snap."
                },
                {
                    h: "Reservoir",
                    b: "The pool lists chips not on the map. Filter by friendly or hardware name. X or Reset clears the filter.\nDrag a chip from the pool onto the photo to place it. Resize the pool; the map does not zoom while the pointer is over it.\nEmpty photo right-click is Draw only — chips come from the pool."
                },
                {
                    h: "Chips",
                    b: "Left-drag moves the chip. The hotspot (dot on the photo) is the hardware contact — drag it separately.\nDefault label is the hardware id: Button 10, Axis 1, Hat 1. Friendly names are optional — Rename to set one. Clear the friendly name to show the hardware id again. Plus / card / mini do not replace that with Up/Left/Push unless you type it.\nRight-click → Chip:\n  Rename — optional friendly label. Empty falls back to Button N / Axis N / Hat N.\n  Font size.\n  Chip size, Round / Square, Filled / Hollow.\n  Colors — Fill, Outline, Text, Pressed fill / outline / text. Color… opens the HSV picker.\n  Highlight on press — live fill when the stick is down.\n  Reset this cell — drop member style overrides (Edit group only).\n  Delete chip — back to the reservoir.\nHotspot (photo input) and Leader End (wire stop) are their own first-level menus, not under Chip.\nDelete / Backspace on a single chip also returns it to the pool.\nYellow ring is selection."
                },
                {
                    h: "Groups",
                    b: "Shift-click or rubber-band two or more chips, then Group → Group selected (Ctrl+G). Extra leaders drop; one remains.\nBreak group (Ctrl+Shift+G) or Delete on a group splits members back to singles.\nEdit group unlocks that group only. Other groups stay locked.\nDouble-click or right-click a member to target it. Drag that member to offset it. Chip style writes to that member only.\nDouble-click the member again to rename it.\nDone editing group or Esc ends the session. Double-click empty photo ends edit and clears the selection.\nSaved group style profiles are not in yet — each group keeps its own format and overrides."
                },
                {
                    h: "Format and Align",
                    b: "Format and Align are first-level drawers, not inside Group.\nFormat → 5-Way (five-member hat groups only):\n  Plus cluster — Up / Left / Push / Right / Down cross. Group name once. One leader.\n  Mini hat — compact U/D/L/R/C glyph.\n  Named card — header plus role-only rows.\n  Radial leaders — spokes from the group (can crowd three hats on this grip).\nPicking the theme that is already on re-applies it: stock layout, cell offsets and style overrides cleared, names kept.\nClear Format under Undo/Redo (group click) or Format → Clear Format strips the 5-Way theme and every cell override (size, shape, colors, offsets). Names, Align, and the group stay. Enabled when a theme or any cell override exists.\nAlign left / center / right / Free layout — only when the target is a group.\nFormat is presentation. Hardware ids stay grouped. Save writes format to control.hardware."
                },
                {
                    h: "Context menu",
                    b: "The first screen follows the click target.\nUndo / Redo always.\nGroup click — Clear Format under Redo when the group has a theme or cell overrides.\nLeader or handle — Add spine, Convert spine, Delete selected spine, Clear spines, then the family drawers.\nChip / group — Chip, Hotspot, Leader End, Group, Format, Align, Leader, Draw.\nEmpty photo — Draw only.\nGray items are gated: no selection, not a group, no handle, or no spines."
                },
                {
                    h: "Hotspot",
                    b: "Hotspot is the input on the photo — the control you press — not the chip label.\nRight-click → Hotspot: Size, Round / Square, Filled / Hollow, Color… (HSV picker).\nThe yellow/white dot on the rig photo is this object."
                },
                {
                    h: "Leader End",
                    b: "Leader End is where the wire stops. It is not the hotspot fill.\nDetach chip end / Detach hotspot end — free that terminus.\nReconnect to this chip / Reconnect to this hotspot — snap it back.\nLeader (the next drawer) still owns line color, weight, extra leaders, and curve."
                },
                {
                    h: "Leaders",
                    b: "A leader is the line from chip (or group) to the hotspot.\nClick the line — select only. A click does not add a spine.\nDrag a segment — plant a curved spine at the grab point, then that handle follows the drag.\nClick a handle — select it (orange).\nShort right-click on a handle — menu. Use Delete selected spine.\nHold right-click about ½ second on a handle — delete that handle, no menu.\nFirst menu on a line or handle: Add spine, Convert spine (flip that handle curved ↔ straight, no check mark), Delete selected spine, Clear spines. Convert and Delete need a selected handle.\nLeader submenu: Color…, Weight 0.8–4.0, Add straight / curved spine, This segment or All segments Curved / Straight, Add leader, Branch from this end, Attach (detach / reconnect chip or hotspot ends), Clear all spines, Delete spine, Delete leader.\nDelete leader applies to every selected chip. Rubber-band several chips, then Leader → Delete leaders — each chip’s line is removed. One chip selected — only that chip’s current leader is removed.\nSpines show only while Edit Mapping is on. The chip-to-hotspot line stays in the live map unless you delete it."
                },
                {
                    h: "Draw",
                    b: "Right-click → Draw.\nAround selection — rectangle, rounded, ellipse, triangle, or diamond around selected chips; it moves with them.\nFree drag — pick a shape, drag on empty photo. Shift locks aspect. Esc or Cancel tool drops the tool. Yellow Drawing in the toolbar means a tool is armed.\nCorner handles resize. Detach from chips turns an around-frame into a free frame.\nShape, Padding, Rotate (0/90/180/270, ±15), Filled / Hollow, Fill color…, Stroke color…, Stroke width, Opacity.\nBring forward / Send back. Hollow frames click through to chips inside.\nOverlay images: File → Import overlay… then transform. A pin sits at the top-left of the plate. Click the pin (or Draw → Pin overlay) to freeze it: the plus clicks through to chips and leaders; only the pin stays live. Click the pin again to unpin and move/resize. Add snap point, Clear snap points. Drop a chip on a white socket to snap. Save writes pinned."
                },
                {
                    h: "Select and move",
                    b: "Click selects. Shift-click or Ctrl-click toggles. Drag empty glass to rubber-band.\nArrows nudge 1 px. Shift+arrows nudge by the grid size.\nDuplicate / Copy / Paste under Edit. Pasted items offset so they do not stack."
                },
                {
                    h: "Keyboard",
                    b: "Ctrl+S Save\nCtrl+Z Undo    Ctrl+Y or Ctrl+Shift+Z Redo\nCtrl+D Duplicate    Ctrl+C Copy    Ctrl+V Paste\nCtrl+G Group    Ctrl+Shift+G Break group\nDelete / Backspace  chip to pool, break group, or delete selected spine\nArrows nudge    Shift+Arrows grid nudge\nEsc  cancel draw tool / end group edit / cancel rename\nF1  this help\nAlt while dragging  skip snap\nShift while drawing  lock aspect"
                },
                {
                    h: "Save and live map",
                    b: "Save writes kind control.hardware for VKBsim Gladiator EVO R. Nodes, image path, and ui (grid) go to the hardware profile.\nThe live face rebinds dest labels from pairing / vJoy / Xbox the same way as before. Theme and chip names are layout only.\nHardware ids on this grip stay locked (buttons 1–29, hat 1, axes 1–4)."
                }
            ]
            delegate: Column {
                width: _helpList.width
                spacing: 4
                required property var modelData
                Label {
                    width: parent.width
                    text: modelData.h
                    color: "#FBBF24"
                    font.pixelSize: 15
                    font.bold: true
                }
                Label {
                    width: parent.width
                    text: modelData.b
                    color: "#E4E4E7"
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                    lineHeight: 1.25
                }
            }
        }
    }

    Dialog {
        id: _resetDlg
        title: "Reset layout"
        modal: true
        anchors.centerIn: parent
        width: 460
        standardButtons: Dialog.NoButton
        closePolicy: Popup.CloseOnEscape
        ColumnLayout {
            anchors.fill: parent
            spacing: 12
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#FBBF24"
                text: "Clear every chip, leader, and hotspot from the map?"
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#A1A1AA"
                text: "Joystick mappings are not changed. Pressed buttons still light in the reservoir. Save after reset if you want the empty layout to become the live map."
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button {
                    text: "Keep map"
                    onClicked: _resetDlg.close()
                }
                Button {
                    text: "Reset layout"
                    highlighted: true
                    onClicked: {
                        _buttonMap.resetLayout()
                        _resetDlg.close()
                    }
                }
            }
        }
        onRejected: close()
    }

    function _ed() {
        return _cardLoader.item ? _cardLoader.item.editorItem : null
    }

    function poolHaystack(row) {
        if (!row)
            return ""
        var hw = row.hwId
        var kind = row.kind || "btn"
        var alias = ""
        if (kind === "axis")
            alias = "axis " + hw + " a" + hw
        else if (kind === "hat")
            alias = "hat " + hw + " h" + hw
        else
            alias = "button " + hw + " btn " + hw + " b" + hw
        return [
            row.friendly || "",
            row.hwName || "",
            row.fullName || "",
            row.dest && row.dest !== "—" ? row.dest : "",
            kind,
            String(hw),
            alias
        ].join(" ").toLowerCase()
    }

    function poolMatches(row, q) {
        if (!q.length)
            return true
        var hay = poolHaystack(row)
        if (hay.indexOf(q) >= 0)
            return true
        var toks = q.split(/\s+/)
        for (var i = 0; i < toks.length; i++) {
            if (!toks[i].length)
                continue
            if (hay.indexOf(toks[i]) < 0)
                return false
        }
        return true
    }

    function refreshReservoir() {
        var e = _ed()
        var all = e ? e.catalog() : []
        var q = (poolFilter || "").trim().toLowerCase()
        var u = []
        for (var i = 0; i < all.length; i++) {
            var row = all[i]
            if (row.placed)
                continue
            if (!poolMatches(row, q))
                continue
            u.push(row)
        }
        resItems = u
    }

    function clearPoolFilter() {
        poolFilter = ""
    }

    function dropPool(vx, vy) {
        var kind = poolKind
        var hw = poolHw
        poolDrag = false
        var ed = _ed()
        if (!ed || !kind || !(hw > 0))
            return
        if (_poolFloat && _poolFloat.visible) {
            var lp = _poolFloat.mapFromItem(_mapHost, vx, vy)
            if (lp.x >= 0 && lp.y >= 0 && lp.x <= _poolFloat.width && lp.y <= _poolFloat.height)
                return
        }
        var local = ed.mapFromItem(_mapHost, vx, vy)
        if (local.x < 0 || local.y < 0 || local.x > ed.width || local.y > ed.height)
            return
        ed.addChiplet(kind, hw, local.x, local.y)
        refreshReservoir()
    }

    function resetLayout() {
        var e = _ed()
        if (e)
            e.pushHist()
        workNodes = []
        if (e)
            e.clearLayout()
        selectedId = ""
        selectedNode = null
        Qt.callLater(refreshReservoir)
    }

    function deleteOrBreak() {
        var e = _ed()
        if (!e)
            return
        var n = e.nodeAt(e.selectedId)
        if (nodeIsGroup(n) || e.isGroup(n))
            e.ungroupSelection()
        else
            e.deleteChip()
        applySelected()
        refreshReservoir()
        _chipPop.close()
    }

    function nodeIsGroup(n) {
        return !!(n && (n.kind === "plus" || n.kind === "pair" || n.kind === "axis_stack" || n.kind === "stack" || (n.members && n.members.length)))
    }

    function applyChipPopSize() {
        var maxW = Math.max(240, _buttonMap.width - 16)
        var maxH = Math.max(200, _buttonMap.height - 16)
        var w = Math.max(240, Math.min(chipPopW, maxW))
        var h = Math.max(200, Math.min(chipPopH, maxH))
        _chipPop.width = w
        _chipPop.height = h
        chipPopW = Math.round(w)
        chipPopH = Math.round(h)
    }

    function rememberChipPopSize() {
        chipPopW = Math.round(_chipPop.width)
        chipPopH = Math.round(_chipPop.height)
        persistChipPopUi()
    }

    function setChipPopSize(w, h) {
        if (w)
            chipPopW = w
        if (h)
            chipPopH = h
        applyChipPopSize()
        persistChipPopUi()
    }

    function uiBag() {
        return {
            chipPopW: chipPopW,
            chipPopH: chipPopH,
            gridOn: gridOn,
            snapOn: snapOn,
            snapEntOn: snapEntOn,
            gridSize: gridSize
        }
    }

    function applyUi(ui) {
        if (!ui)
            return
        if (ui.chipPopW >= 240)
            chipPopW = ui.chipPopW
        if (ui.chipPopH >= 200)
            chipPopH = ui.chipPopH
        if (ui.gridOn === true || ui.gridOn === false)
            gridOn = ui.gridOn
        if (ui.snapOn === true || ui.snapOn === false)
            snapOn = ui.snapOn
        if (ui.snapEntOn === true || ui.snapEntOn === false)
            snapEntOn = ui.snapEntOn
        if (ui.gridSize >= 4)
            gridSize = ui.gridSize
    }

    function applyGridToEditor() {
        var e = _cardLoader.item ? _cardLoader.item.editorItem : null
        if (!e)
            return
        e.gridOn = gridOn
        e.snapOn = snapOn
        e.snapEntOn = snapEntOn
        e.gridSize = gridSize
        if (e.repaint)
            e.repaint()
    }

    function persistUi() {
        var text = _hw.load(targetName)
        var doc = parseDoc(text)
        if (!doc) {
            doc = {
                kind: "control.hardware",
                device: targetName,
                image: liveImage.length ? liveImage : stockImage,
                nodes: liveNodes || []
            }
        }
        doc.ui = uiBag()
        _hw.save(targetName, JSON.stringify(doc))
    }

    function persistChipPopUi() {
        persistUi()
    }

    function setGridPref(key, val) {
        if (key === "gridOn") gridOn = val
        else if (key === "snapOn") snapOn = val
        else if (key === "snapEntOn") snapEntOn = val
        else if (key === "gridSize") gridSize = val
        applyGridToEditor()
        persistUi()
    }

    function openChipMenu(x, y) {
        applySelected()
    }

    Menu {
        id: _groupMenu
        MenuItem { text: "Group selected"; onTriggered: { var e = _ed(); if (e) e.groupSelection() } }
        MenuItem { text: "Break group"; onTriggered: { var e = _ed(); if (e) e.ungroupSelection() } }
        MenuSeparator {}
        MenuItem { text: "Edit group"; onTriggered: { var e = _ed(); if (e) e.beginGroupEdit(e.selectedId) } }
        MenuItem { text: "Done editing group"; onTriggered: { var e = _ed(); if (e) e.endGroupEdit() } }
        MenuSeparator {}
        Menu {
            title: "Apply Format"
            enabled: {
                var e = _ed()
                return !!(e && e.isFiveWay(e.nodeAt(e.selectedId)))
            }
            Menu {
                title: "5-Way"
                MenuItem {
                    text: "Plus cluster"
                    checkable: true
                    checked: { var e = _ed(); return !!(e && e.fiveWayFormat(e.nodeAt(e.selectedId)) === "plus") }
                    onTriggered: { var e = _ed(); if (e) e.applyFiveWayFormat("plus") }
                }
                MenuItem {
                    text: "Mini hat"
                    checkable: true
                    checked: { var e = _ed(); return !!(e && e.fiveWayFormat(e.nodeAt(e.selectedId)) === "mini") }
                    onTriggered: { var e = _ed(); if (e) e.applyFiveWayFormat("mini") }
                }
                MenuItem {
                    text: "Named card"
                    checkable: true
                    checked: { var e = _ed(); return !!(e && e.fiveWayFormat(e.nodeAt(e.selectedId)) === "card") }
                    onTriggered: { var e = _ed(); if (e) e.applyFiveWayFormat("card") }
                }
                MenuItem {
                    text: "Radial leaders"
                    checkable: true
                    checked: { var e = _ed(); return !!(e && e.fiveWayFormat(e.nodeAt(e.selectedId)) === "radial") }
                    onTriggered: { var e = _ed(); if (e) e.applyFiveWayFormat("radial") }
                }
            }
        }
        MenuSeparator {}
        MenuItem { text: "Align left"; onTriggered: { var e = _ed(); if (e) e.setAlignH("left") } }
        MenuItem { text: "Align center"; onTriggered: { var e = _ed(); if (e) e.setAlignH("center") } }
        MenuItem { text: "Align right"; onTriggered: { var e = _ed(); if (e) e.setAlignH("right") } }
        MenuItem { text: "Free layout"; onTriggered: { var e = _ed(); if (e) e.setAlignH("free") } }
    }

    Menu {
        id: _leadMenu
        MenuItem { text: "Add straight spine"; onTriggered: { var e = _ed(); if (e && selectedNode) { e.ensureMidSpine(selectedNode); e.bump() } } }
        MenuItem { text: "Add curved spine"; onTriggered: { var e = _ed(); if (e && selectedNode) e.addCurveSpine(selectedNode) } }
        MenuItem { text: "This segment curved"; onTriggered: { var e = _ed(); if (e) e.setSegCurve(e.currentLeader(e.nodeAt(e.selectedId)), Math.max(0, e.selectedSeg), true) } }
        MenuItem { text: "This segment straight"; onTriggered: { var e = _ed(); if (e) e.setSegCurve(e.currentLeader(e.nodeAt(e.selectedId)), Math.max(0, e.selectedSeg), false) } }
        MenuItem { text: "All segments curved"; onTriggered: { var e = _ed(); if (e) e.setAllSegCurve(true) } }
        MenuItem { text: "All segments straight"; onTriggered: { var e = _ed(); if (e) e.setAllSegCurve(false) } }
        MenuSeparator {}
        MenuItem { text: "Add leader (same chip / hotspot)"; onTriggered: { var e = _ed(); if (e) e.addLeader() } }
        MenuItem { text: "Branch from this end"; onTriggered: { var e = _ed(); if (e) e.addBranch() } }
        MenuItem { text: "Delete leader"; onTriggered: { var e = _ed(); if (e) e.deleteLeader() } }
        MenuSeparator {}
        MenuItem { text: "Detach chip end"; onTriggered: { var e = _ed(); if (e) e.detachEnd("from") } }
        MenuItem { text: "Detach hotspot end"; onTriggered: { var e = _ed(); if (e) e.detachEnd("to") } }
        MenuItem { text: "Reconnect to this chip"; onTriggered: { var e = _ed(); if (e) e.attachEndToSelf("from") } }
        MenuItem { text: "Reconnect to this hotspot"; onTriggered: { var e = _ed(); if (e) e.attachEndToSelf("to") } }
        MenuItem { text: "Delete selected spine"; onTriggered: { var e = _ed(); if (e) e.deleteSelection() } }
    }

    FileDialog {
        id: _imageDialog
        title: "Choose background image"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            var rel = _hw.copyImage(selectedFile, targetName)
            if (rel.length) {
                applyImage(rel)
            }
        }
    }

    FileDialog {
        id: _overlayDialog
        title: "Import overlay image"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: {
            var rel = _hw.copyOverlay(selectedFile, targetName)
            var e = _ed()
            if (rel.length && e)
                e.addOverlay(rel, _hw.imageUrl(rel))
        }
    }

    Popup {
        id: _savedPop
        modal: true
        dim: false
        focus: true
        padding: 16
        closePolicy: _buttonMap.saveOk
                     ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
                     : Popup.NoAutoClose
        parent: Overlay.overlay
        x: Overlay.overlay ? Math.round((Overlay.overlay.width - width) / 2) : Math.round((_buttonMap.width - width) / 2)
        y: Overlay.overlay ? Math.round((Overlay.overlay.height - height) / 2) : Math.round((_buttonMap.height - height) / 2)
        background: Rectangle {
            color: _buttonMap.saveOk ? "#18181B" : "#450A0A"
            border.color: _buttonMap.saveOk ? "#3F3F46" : "#DC2626"
            border.width: 1
            radius: 4
        }
        contentItem: Column {
            spacing: 12
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: _buttonMap.saveOk ? "Mapping saved" : "Save failed"
                color: _buttonMap.saveOk ? "#E4E4E7" : "#FECACA"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
            Button {
                visible: !_buttonMap.saveOk
                anchors.horizontalCenter: parent.horizontalCenter
                text: "OK"
                onClicked: _savedPop.close()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        MenuBar {
            Layout.fillWidth: true
            Menu {
                title: "File"
                MenuItem {
                    text: "Edit Mapping"
                    enabled: !_buttonMap.editing
                    onTriggered: _buttonMap.enterEdit()
                }
                MenuItem { text: "Save"; enabled: _buttonMap.editing; onTriggered: _buttonMap.saveEdit() }
                MenuItem { text: "Cancel"; enabled: _buttonMap.editing; onTriggered: _buttonMap.cancelEdit() }
                MenuSeparator {}
                MenuItem { text: "Reset layout"; enabled: editing; onTriggered: _resetDlg.open() }
                MenuSeparator {}
                MenuItem { text: "Choose background…"; enabled: editing; onTriggered: _imageDialog.open() }
                MenuItem {
                    text: "Import overlay…"
                    enabled: editing
                    onTriggered: _overlayDialog.open()
                }
                MenuItem {
                    text: "Clear image"
                    enabled: editing
                    onTriggered: {
                        _hw.clearImage(targetName)
                        applyImage(stockImage)
                    }
                }
                MenuSeparator {}
                MenuItem {
                    text: "Exit"
                    onTriggered: _buttonMap.close()
                }
            }
            Menu {
                title: "Edit"
                MenuItem {
                    text: "Undo"
                    enabled: { var e = _ed(); return e ? e.canUndo : false }
                    onTriggered: { var e = _ed(); if (e) e.undo() }
                }
                MenuItem {
                    text: "Redo"
                    enabled: { var e = _ed(); return e ? e.canRedo : false }
                    onTriggered: { var e = _ed(); if (e) e.redo() }
                }
                MenuSeparator {}
                MenuItem {
                    text: "Duplicate"
                    enabled: { var e = _ed(); return e && e.selectedId !== "" }
                    onTriggered: { var e = _ed(); if (e) e.duplicateSelection() }
                }
                MenuItem {
                    text: "Copy"
                    enabled: { var e = _ed(); return e && e.selectedId !== "" }
                    onTriggered: { var e = _ed(); if (e) e.copySelection() }
                }
                MenuItem {
                    text: "Paste"
                    enabled: { var e = _ed(); return e && e.clip && e.clip.length }
                    onTriggered: { var e = _ed(); if (e) e.pasteClipboard() }
                }
            }
            Menu {
                title: "View"
                MenuItem {
                    text: "Reset view"
                    onTriggered: {
                        if (_cardLoader.item)
                            _cardLoader.item.resetView()
                    }
                }
                MenuSeparator {}
                Menu {
                    title: "Grid"
                    MenuItem {
                        text: "Show grid"
                        checkable: true
                        checked: _buttonMap.gridOn
                        onTriggered: _buttonMap.setGridPref("gridOn", checked)
                    }
                    MenuItem {
                        text: "Snap to grid"
                        checkable: true
                        checked: _buttonMap.snapOn
                        onTriggered: _buttonMap.setGridPref("snapOn", checked)
                    }
                    MenuItem {
                        text: "Snap to entities"
                        checkable: true
                        checked: _buttonMap.snapEntOn
                        onTriggered: _buttonMap.setGridPref("snapEntOn", checked)
                    }
                    MenuSeparator {}
                    Menu {
                        title: "Size"
                        MenuItem {
                            text: "4"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 4 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 4)
                        }
                        MenuItem {
                            text: "8"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 8 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 8)
                        }
                        MenuItem {
                            text: "12"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 12 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 12)
                        }
                        MenuItem {
                            text: "16"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 16 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 16)
                        }
                        MenuItem {
                            text: "24"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 24 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 24)
                        }
                        MenuItem {
                            text: "32"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 32 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 32)
                        }
                        MenuItem {
                            text: "48"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 48 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 48)
                        }
                        MenuItem {
                            text: "64"
                            checkable: true
                            checked: { var e = _ed(); return e && e.gridSize === 64 }
                            onTriggered: _buttonMap.setGridPref("gridSize", 64)
                        }
                    }
                }
            }
            Menu {
                title: "Help"
                MenuItem {
                    text: "Editor help"
                    onTriggered: _helpDlg.open()
                }
            }
        }

        ToolBar {
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Label {
                    visible: editing
                    text: _cardLoader.item ? (Math.round(_cardLoader.item.zoom * 100) + "%") : "100%"
                    color: "#E4E4E7"
                    font.pixelSize: 12
                }
                Label {
                    visible: {
                        resTick
                        var e = _ed()
                        return editing && e && e.drawTool && e.drawTool.length
                    }
                    text: "Drawing — drag empty. Shift locks aspect. Esc cancels."
                    color: "#FBBF24"
                    font.pixelSize: 12
                }
                Label {
                    visible: editing
                    text: "control.hardware  " + _hw.path
                    color: "#A1A1AA"
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Shortcut {
                    enabled: editing
                    sequence: "Delete"
                    onActivated: deleteOrBreak()
                }
                Shortcut {
                    enabled: editing
                    sequence: "Backspace"
                    onActivated: deleteOrBreak()
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+Z"
                    onActivated: { var e = _ed(); if (e) e.undo() }
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+Shift+Z"
                    onActivated: { var e = _ed(); if (e) e.redo() }
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+Y"
                    onActivated: { var e = _ed(); if (e) e.redo() }
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+G"
                    onActivated: { var e = _ed(); if (e) e.groupSelection() }
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+Shift+G"
                    onActivated: { var e = _ed(); if (e) e.ungroupSelection() }
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+D"
                    onActivated: { var e = _ed(); if (e) e.duplicateSelection() }
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+C"
                    onActivated: { var e = _ed(); if (e) e.copySelection() }
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+V"
                    onActivated: { var e = _ed(); if (e) e.pasteClipboard() }
                }
                Shortcut {
                    sequence: "F1"
                    onActivated: _helpDlg.open()
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+S"
                    onActivated: saveEdit()
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+0"
                    onActivated: {
                        if (_cardLoader.item)
                            _cardLoader.item.resetView()
                    }
                }
                Item { Layout.fillWidth: true; visible: !editing }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                id: _mapHost
                Layout.fillWidth: true
                Layout.fillHeight: true

                JGText {
                    anchors.centerIn: parent
                    visible: !_hasTarget.hit
                    text: "Connect VKBsim Gladiator EVO R"
                    opacity: 0.65
                }

                QtObject {
                    id: _hasTarget
                    property bool hit: false
                }

                Component {
                    id: _cardComp
                    JoystickButtonMapCard {
                        id: _card
                        anchors.fill: parent
                        deviceGuid: parent.dGuid
                        title: _buttonMap.displayName(parent.dGuid, parent.dName)
                        pairLabel: parent.dPair
                        editing: _buttonMap.editing
                        editorNodes: _buttonMap.editing ? _buttonMap.workNodes : _buttonMap.liveNodes
                        photoOverride: _buttonMap.photoOverride
                        Connections {
                            target: _card.editorItem
                            function onSelectedChanged() { _buttonMap.applySelected() }
                            function onTickChanged() { _buttonMap.resTick++ }
                            function onChipMenuRequested(x, y) { _buttonMap.openChipMenu(x, y) }
                            function onColorPickRequested(field, hex) { _buttonMap.openColorField(field, hex, null) }
                            function onDrawToolChanged() { _buttonMap.resTick++ }
                            function onHistoryChanged() {
                                _buttonMap.applySelected()
                                _buttonMap.refreshReservoir()
                            }
                            function onNodesChanged() {
                                _buttonMap.applySelected()
                                _buttonMap.refreshReservoir()
                            }
                        }
                        Component.onCompleted: _cardLoader.item = _card
                    }
                }

                Repeater {
                    model: _devices
                    Loader {
                        id: _slot
                        required property string guid
                        required property string name
                        required property string pairLabel
                        required property bool mapped
                        anchors.fill: parent
                        active: _buttonMap.isTarget(guid, name)
                        visible: active
                        property string dGuid: guid
                        property string dName: name
                        property string dPair: pairLabel
                        sourceComponent: _cardComp
                        onActiveChanged: if (active) _hasTarget.hit = true
                        onLoaded: {
                            _hasTarget.hit = true
                            _cardLoader.item = item
                            Qt.callLater(_buttonMap.applyGridToEditor)
                        }
                    }
                }

                QtObject {
                    id: _cardLoader
                    property var item: null
                }

                Item {
                    id: _poolFloat
                    visible: editing
                    z: 30
                    x: 12
                    width: 280
                    height: 160
                    onVisibleChanged: if (visible) Qt.callLater(clampPool)

                    component PoolGrip: MouseArea {
                        required property string edge
                        preventStealing: true
                        hoverEnabled: true
                        onPressed: (m) => startPanelResize(edge, m.x, m.y, this)
                        onPositionChanged: (m) => {
                            if (pressed)
                                movePanelResize(m.x, m.y, this)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 0
                        acceptedButtons: Qt.AllButtons
                        hoverEnabled: true
                        onPressed: (m) => { m.accepted = true }
                        onClicked: (m) => { m.accepted = true }
                        onDoubleClicked: (m) => { m.accepted = true }
                        onWheel: (w) => { w.accepted = true }
                    }

                    Rectangle {
                        anchors.fill: parent
                        z: 1
                        radius: 12
                        color: "#CC0C0C0E"
                        border.color: "#3F3F46"
                    }
                    ColumnLayout {
                        z: 2
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.bottomMargin: 12
                        anchors.rightMargin: 10
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                TextField {
                                    id: _poolSearch
                                    anchors.fill: parent
                                    placeholderText: "Filter friendly or hardware"
                                    text: poolFilter
                                    rightPadding: 26
                                    onTextChanged: {
                                        if (poolFilter !== text)
                                            poolFilter = text
                                    }
                                }
                                Text {
                                    visible: poolFilter.length > 0
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "×"
                                    color: "#A1A1AA"
                                    font.pixelSize: 16
                                    z: 2
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clearPoolFilter()
                                    }
                                }
                            }
                            Button {
                                text: "Reset"
                                implicitHeight: 28
                                onClicked: clearPoolFilter()
                            }
                        }
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            interactive: !_buttonMap.poolDrag
                            pressDelay: 0
                            contentWidth: width
                            contentHeight: _resFlow.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            Flow {
                                id: _resFlow
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: resItems
                                    delegate: Rectangle {
                                        required property var modelData
                                        property bool lit: {
                                            var t = _buttonMap.resTick
                                            var e = _ed()
                                            if (!e || !modelData)
                                                return false
                                            return e.litOf(modelData.kind, modelData.hwId)
                                        }
                                        implicitWidth: Math.min(260, _chipLab.implicitWidth + 18)
                                        implicitHeight: 26
                                        radius: 13
                                        color: lit ? "#14532D" : "#18181B"
                                        border.color: lit ? "#22C55E" : "#3F3F46"
                                        border.width: lit ? 2 : 1
                                        opacity: (_buttonMap.poolDrag && _buttonMap.poolHw === (modelData ? modelData.hwId : -1) && _buttonMap.poolKind === (modelData ? modelData.kind : "")) ? 0.35 : 1
                                        Text {
                                            id: _chipLab
                                            anchors.centerIn: parent
                                            text: modelData ? modelData.friendly : ""
                                            color: lit ? "#BBF7D0" : "#E4E4E7"
                                            font.pixelSize: 11
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            z: 2
                                            hoverEnabled: true
                                            preventStealing: true
                                            cursorShape: Qt.OpenHandCursor
                                            onPressed: (m) => {
                                                if (!modelData)
                                                    return
                                                var p = mapToItem(_mapHost, m.x, m.y)
                                                _buttonMap.poolKind = modelData.kind
                                                _buttonMap.poolHw = modelData.hwId
                                                _buttonMap.poolName = modelData.friendly
                                                _buttonMap.poolX = p.x
                                                _buttonMap.poolY = p.y
                                                _buttonMap.poolDrag = true
                                            }
                                            onPositionChanged: (m) => {
                                                if (!_buttonMap.poolDrag)
                                                    return
                                                var p = mapToItem(_mapHost, m.x, m.y)
                                                _buttonMap.poolX = p.x
                                                _buttonMap.poolY = p.y
                                            }
                                            onReleased: (m) => {
                                                if (!_buttonMap.poolDrag)
                                                    return
                                                var p = mapToItem(_mapHost, m.x, m.y)
                                                dropPool(p.x, p.y)
                                            }
                                            onCanceled: _buttonMap.poolDrag = false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PoolGrip { edge: "n"; z: 3; height: 6; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; cursorShape: Qt.SizeVerCursor }
                    PoolGrip { edge: "s"; z: 3; height: 6; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; cursorShape: Qt.SizeVerCursor }
                    PoolGrip { edge: "w"; z: 3; width: 6; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; cursorShape: Qt.SizeHorCursor }
                    PoolGrip { edge: "e"; z: 3; width: 6; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; cursorShape: Qt.SizeHorCursor }
                    PoolGrip { edge: "nw"; z: 3; width: 12; height: 12; anchors.left: parent.left; anchors.top: parent.top; cursorShape: Qt.SizeFDiagCursor }
                    PoolGrip { edge: "ne"; z: 3; width: 12; height: 12; anchors.right: parent.right; anchors.top: parent.top; cursorShape: Qt.SizeBDiagCursor }
                    PoolGrip { edge: "sw"; z: 3; width: 12; height: 12; anchors.left: parent.left; anchors.bottom: parent.bottom; cursorShape: Qt.SizeBDiagCursor }
                    PoolGrip { edge: "se"; z: 4; width: 14; height: 14; anchors.right: parent.right; anchors.bottom: parent.bottom; cursorShape: Qt.SizeFDiagCursor }

                    Item {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 3
                        width: 10
                        height: 10
                        opacity: 0.55
                        Rectangle { width: 8; height: 1; color: "#A1A1AA"; rotation: -45; x: 2; y: 7 }
                        Rectangle { width: 5; height: 1; color: "#A1A1AA"; rotation: -45; x: 5; y: 8 }
                    }
                }

                Connections {
                    target: _mapHost
                    function onWidthChanged() { if (editing) clampPool() }
                    function onHeightChanged() { if (editing) clampPool() }
                }

                MouseArea {
                    id: _poolCatch
                    anchors.fill: parent
                    z: 40
                    visible: poolDrag
                    hoverEnabled: true
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton
                    onPositionChanged: (m) => {
                        poolX = m.x
                        poolY = m.y
                    }
                    onReleased: (m) => dropPool(m.x, m.y)
                    onCanceled: poolDrag = false
                }
            }

        }
    }

    Popup {
        id: _chipPop
        parent: _buttonMap.contentItem
        width: 280
        height: 480
        modal: false
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape
        property real _rsx: 0
        property real _rsy: 0
        property real _rsw: 0
        property real _rsh: 0
        property real _rmx: 0
        property real _rmy: 0
        property string _redge: ""

        function startResize(edge, mx, my, item) {
            _redge = edge
            _rsx = x
            _rsy = y
            _rsw = width
            _rsh = height
            var p = item.mapToItem(parent, mx, my)
            _rmx = p.x
            _rmy = p.y
        }

        function moveResize(mx, my, item) {
            var p = item.mapToItem(parent, mx, my)
            var dx = p.x - _rmx
            var dy = p.y - _rmy
            var nx = _rsx
            var ny = _rsy
            var nw = _rsw
            var nh = _rsh
            var e = _redge
            if (e.indexOf("e") >= 0)
                nw = _rsw + dx
            if (e.indexOf("s") >= 0)
                nh = _rsh + dy
            if (e.indexOf("w") >= 0)
                nw = _rsw - dx
            if (e.indexOf("n") >= 0)
                nh = _rsh - dy
            var maxW = Math.max(240, parent.width - 16)
            var maxH = Math.max(200, parent.height - 16)
            nw = Math.max(240, Math.min(nw, maxW))
            nh = Math.max(200, Math.min(nh, maxH))
            if (e.indexOf("w") >= 0)
                nx = _rsx + _rsw - nw
            if (e.indexOf("n") >= 0)
                ny = _rsy + _rsh - nh
            nx = Math.max(8, Math.min(nx, parent.width - nw - 8))
            ny = Math.max(8, Math.min(ny, parent.height - nh - 8))
            x = nx
            y = ny
            width = nw
            height = nh
            chipPopW = Math.round(nw)
            chipPopH = Math.round(nh)
        }

        function startMove(mx, my, item) {
            _rsx = x
            _rsy = y
            var p = item.mapToItem(parent, mx, my)
            _rmx = p.x
            _rmy = p.y
        }

        function moveWin(mx, my, item) {
            var p = item.mapToItem(parent, mx, my)
            x = Math.max(8, Math.min(_rsx + p.x - _rmx, parent.width - width - 8))
            y = Math.max(8, Math.min(_rsy + p.y - _rmy, parent.height - height - 8))
        }

        background: Rectangle {
            color: "#111113"
            border.color: "#3F3F46"
            radius: 8
        }

        component Grip: MouseArea {
            required property string edge
            preventStealing: true
            hoverEnabled: true
            onPressed: (m) => _chipPop.startResize(edge, m.x, m.y, this)
            onPositionChanged: (m) => {
                if (pressed)
                    _chipPop.moveResize(m.x, m.y, this)
            }
            onReleased: rememberChipPopSize()
        }
        MouseArea {
            id: _chipDrag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            onPressed: (m) => _chipPop.startMove(m.x, m.y, this)
            onPositionChanged: (m) => {
                if (pressed)
                    _chipPop.moveWin(m.x, m.y, this)
            }
            ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            anchors.bottomMargin: 14
            anchors.rightMargin: 12
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Button {
                    text: "Undo"
                    implicitHeight: 24
                    enabled: { var e = _ed(); return e ? e.canUndo : false }
                    onClicked: { var e = _ed(); if (e) e.undo() }
                }
                Button {
                    text: "Redo"
                    implicitHeight: 24
                    enabled: { var e = _ed(); return e ? e.canRedo : false }
                    onClicked: { var e = _ed(); if (e) e.redo() }
                }
                Button {
                    text: "Group"
                    implicitHeight: 24
                    onClicked: _groupMenu.popup()
                }
                Button {
                    text: "Break group"
                    implicitHeight: 24
                    visible: nodeIsGroup(selectedNode)
                    onClicked: {
                        var e = _ed()
                        if (e)
                            e.ungroupSelection()
                        applySelected()
                        refreshReservoir()
                        _chipPop.close()
                    }
                }
                Button {
                    text: "Leader"
                    implicitHeight: 24
                    onClicked: _leadMenu.popup()
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "×"
                    implicitWidth: 28
                    implicitHeight: 24
                    onClicked: _chipPop.close()
                }
            }
            Label {
                text: selectedNode ? (selectedNode.friendly || selectedNode.id || "Chip") : "Chip"
                font.bold: true
                color: "#E4E4E7"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#A1A1AA"
                font.pixelSize: 11
                text: {
                    var e = _ed()
                    var n = selectedNode
                    if (!n || !e)
                        return ""
                    if (n.members && n.members.length) {
                        var parts = []
                        var lk = n.kind === "axis_stack" ? "axis" : "btn"
                        for (var i = 0; i < n.members.length; i++)
                            parts.push(e.fullNameOf(lk, n.members[i].hwId))
                        return parts.join("\n")
                    }
                    return e.fullNameOf(n.kind, n.hwId)
                }
            }
            Flickable {
                id: _chipFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                interactive: false
                contentWidth: width
                contentHeight: _chipForm.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                WheelHandler {
                    onWheel: (w) => {
                        var ny = _chipFlick.contentY - w.angleDelta.y * 0.5
                        var maxY = Math.max(0, _chipFlick.contentHeight - _chipFlick.height)
                        _chipFlick.contentY = Math.max(0, Math.min(maxY, ny))
                        w.accepted = true
                    }
                }
                ColumnLayout {
                    id: _chipForm
                    width: parent.width
                    spacing: 6

                    Label { text: "Friendly name"; color: "#A1A1AA" }
                    TextField {
                        Layout.fillWidth: true
                        text: selectedNode && selectedNode.friendly ? selectedNode.friendly : (selectedNode && selectedNode.label ? selectedNode.label : "")
                        placeholderText: "shown on the chip"
                        onEditingFinished: {
                            if (selectedNode) {
                                selectedNode.friendly = text
                                selectedNode.label = text
                                var e = _ed()
                                if (e) e.bump()
                            }
                        }
                    }

                    Label { text: "Group align"; color: "#A1A1AA"; visible: nodeIsGroup(selectedNode) }
                    RowLayout {
                        visible: nodeIsGroup(selectedNode)
                        Layout.fillWidth: true
                        spacing: 4
                        Button { text: "Left"; checkable: true; checked: selectedNode && selectedNode.alignH === "left"; onClicked: { var e = _ed(); if (e) e.setAlignH("left") } }
                        Button { text: "Center"; checkable: true; checked: !selectedNode || !selectedNode.alignH || selectedNode.alignH === "center"; onClicked: { var e = _ed(); if (e) e.setAlignH("center") } }
                        Button { text: "Right"; checkable: true; checked: selectedNode && selectedNode.alignH === "right"; onClicked: { var e = _ed(); if (e) e.setAlignH("right") } }
                        Button { text: "Free"; checkable: true; checked: selectedNode && selectedNode.alignH === "free"; onClicked: { var e = _ed(); if (e) e.setAlignH("free") } }
                    }

                    Label { text: "Hardware id"; color: "#A1A1AA"; visible: selectedNode && selectedNode.hwId !== undefined && !nodeIsGroup(selectedNode) }
                    SpinBox {
                        visible: selectedNode && selectedNode.hwId !== undefined && !nodeIsGroup(selectedNode)
                        from: 1
                        to: 64
                        value: selectedNode && selectedNode.hwId ? selectedNode.hwId : 1
                        onValueModified: {
                            if (selectedNode) {
                                selectedNode.hwId = value
                                var e = _ed()
                                if (e) e.bump()
                            }
                        }
                    }

                    Label { text: "Font size"; color: "#A1A1AA" }
                    SpinBox {
                        from: 8
                        to: 22
                        value: selectedNode && selectedNode.fontSize ? selectedNode.fontSize : 10
                        onValueModified: { var e = _ed(); if (e) e.applyField("fontSize", value) }
                    }
                    Label { text: "Chip size"; color: "#A1A1AA" }
                    SpinBox {
                        from: 12
                        to: 48
                        value: selectedNode && selectedNode.chipSize ? selectedNode.chipSize : 18
                        onValueModified: { var e = _ed(); if (e) e.applyField("chipSize", value) }
                    }
                    Label { text: "Chip shape"; color: "#A1A1AA" }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Round", "Square"]
                        currentIndex: selectedNode && selectedNode.chipShape === "square" ? 1 : 0
                        onActivated: (idx) => { var e = _ed(); if (e) e.applyField("chipShape", idx === 1 ? "square" : "round") }
                    }
                    Label { text: "Chip fill"; color: "#A1A1AA" }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Filled", "Hollow"]
                        currentIndex: selectedNode && selectedNode.chipFill === "hollow" ? 1 : 0
                        onActivated: (idx) => { var e = _ed(); if (e) e.applyField("chipFill", idx === 1 ? "hollow" : "filled") }
                    }
                    Label { text: "Hotspot size"; color: "#A1A1AA" }
                    SpinBox {
                        from: 4
                        to: 28
                        value: selectedNode && selectedNode.hotSize ? selectedNode.hotSize : 9
                        onValueModified: { var e = _ed(); if (e) e.applyField("hotSize", value) }
                    }
                    Label { text: "Hotspot shape"; color: "#A1A1AA" }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Round", "Square"]
                        currentIndex: selectedNode && selectedNode.hotShape === "square" ? 1 : 0
                        onActivated: (idx) => { var e = _ed(); if (e) e.applyField("hotShape", idx === 1 ? "square" : "round") }
                    }
                    Label { text: "Hotspot fill"; color: "#A1A1AA" }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Filled", "Hollow"]
                        currentIndex: selectedNode && selectedNode.hotFill === "hollow" ? 1 : 0
                        onActivated: (idx) => { var e = _ed(); if (e) e.applyField("hotFill", idx === 1 ? "hollow" : "filled") }
                    }
                    CheckBox {
                        text: "Highlight on press"
                        checked: selectedNode ? selectedNode.highlight !== false : true
                        onToggled: {
                            if (selectedNode) {
                                selectedNode.highlight = checked
                                var e = _ed()
                                if (e) e.bump()
                            }
                        }
                    }
                    Label { text: "Colors"; color: "#A1A1AA" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 6
                        Label { text: "Fill"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.color ? selectedNode.color : "#18181B"; onPicked: _colorPop.openField("color", hex, this) }
                        Label { text: "Outline"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.border ? selectedNode.border : "#3F3F46"; onPicked: _colorPop.openField("border", hex, this) }
                        Label { text: "Text"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.textColor ? selectedNode.textColor : "#E4E4E7"; onPicked: _colorPop.openField("textColor", hex, this) }
                        Label { text: "Highlight"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.hlColor ? selectedNode.hlColor : "#14532D"; onPicked: _colorPop.openField("hlColor", hex, this) }
                        Label { text: "Pressed outline"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.hlBorder ? selectedNode.hlBorder : "#22C55E"; onPicked: _colorPop.openField("hlBorder", hex, this) }
                        Label { text: "HL text"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.hlText ? selectedNode.hlText : "#BBF7D0"; onPicked: _colorPop.openField("hlText", hex, this) }
                        Label { text: "Leader"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.leaderColor ? selectedNode.leaderColor : "#A1A1AA"; onPicked: _colorPop.openField("leaderColor", hex, this) }
                        Label { text: "Hotspot"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.hotColor ? selectedNode.hotColor : "#F4F4F5"; onPicked: _colorPop.openField("hotColor", hex, this) }
                    }
                    Label { text: "Leader weight"; color: "#A1A1AA" }
                    Slider {
                        Layout.fillWidth: true
                        from: 5
                        to: 40
                        stepSize: 1
                        value: selectedNode && selectedNode.leaderWidth > 0 ? selectedNode.leaderWidth * 10 : 11
                        onMoved: {
                            var e = _ed()
                            if (e)
                                e.applyField("leaderWidth", value / 10)
                        }
                    }
                    Button {
                        text: "Delete chip"
                        Layout.fillWidth: true
                        enabled: !nodeIsGroup(selectedNode)
                        onClicked: {
                            if (nodeIsGroup(selectedNode))
                                return
                            var e = _ed()
                            if (e)
                                e.deleteChip()
                            selectedId = ""
                            selectedNode = null
                            refreshReservoir()
                            _chipPop.close()
                        }
                    }
                }
            }
        }
        }

        Grip { edge: "n"; height: 6; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; cursorShape: Qt.SizeVerCursor }
        Grip { edge: "s"; height: 6; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; cursorShape: Qt.SizeVerCursor }
        Grip { edge: "w"; width: 6; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; cursorShape: Qt.SizeHorCursor }
        Grip { edge: "e"; width: 6; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; cursorShape: Qt.SizeHorCursor }
        Grip { edge: "nw"; width: 12; height: 12; anchors.left: parent.left; anchors.top: parent.top; cursorShape: Qt.SizeFDiagCursor }
        Grip { edge: "ne"; width: 12; height: 12; anchors.right: parent.right; anchors.top: parent.top; cursorShape: Qt.SizeBDiagCursor }
        Grip { edge: "sw"; width: 12; height: 12; anchors.left: parent.left; anchors.bottom: parent.bottom; cursorShape: Qt.SizeBDiagCursor }
        Grip { edge: "se"; width: 14; height: 14; anchors.right: parent.right; anchors.bottom: parent.bottom; cursorShape: Qt.SizeFDiagCursor; z: 2 }

        Item {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: 10
            height: 10
            opacity: 0.55
            Rectangle { width: 8; height: 1; color: "#A1A1AA"; rotation: -45; x: 2; y: 7 }
            Rectangle { width: 5; height: 1; color: "#A1A1AA"; rotation: -45; x: 5; y: 8 }
        }
    }

    Rectangle {
        id: _poolGhost
        parent: _mapHost
        visible: poolDrag && editing
        z: 2000
        width: Math.max(36, _ghostLab.implicitWidth + 18)
        height: 26
        radius: 13
        x: poolX - width * 0.5
        y: poolY - height * 0.5
        color: "#14532D"
        border.color: "#4ADE80"
        border.width: 1
        Text {
            id: _ghostLab
            anchors.centerIn: parent
            text: poolName
            color: "#BBF7D0"
            font.pixelSize: 11
        }
    }

    component ColorSwatch: Rectangle {
        id: _sw
        property string hex: "#18181B"
        signal picked()
        Layout.preferredWidth: 72
        Layout.preferredHeight: 24
        width: 72
        height: 24
        radius: 4
        color: hex
        border.color: "#52525B"
        border.width: 1
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: _sw.picked()
        }
    }

    function _toHex(c) {
        var r = Math.round(c.r * 255)
        var g = Math.round(c.g * 255)
        var b = Math.round(c.b * 255)
        if (r < 0) r = 0
        if (r > 255) r = 255
        if (g < 0) g = 0
        if (g > 255) g = 255
        if (b < 0) b = 0
        if (b > 255) b = 255
        var rs = r.toString(16)
        var gs = g.toString(16)
        var bs = b.toString(16)
        if (rs.length < 2) rs = "0" + rs
        if (gs.length < 2) gs = "0" + gs
        if (bs.length < 2) bs = "0" + bs
        return "#" + rs + gs + bs
    }

    Popup {
        id: _colorPop
        parent: _buttonMap.contentItem
        width: 248
        height: 330
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 10
        property string field: "color"
        property real hh: 0
        property real ss: 0
        property real vv: 0.12
        readonly property color live: Qt.hsva(hh, ss, vv, 1)
        background: Rectangle {
            color: "#18181B"
            border.color: "#3F3F46"
            radius: 8
        }

        function openField(field, hex, anchorItem) {
            _colorPop.field = field
            var c = Qt.color(hex && hex.length ? hex : "#18181B")
            hh = c.hsvHue < 0 ? 0 : c.hsvHue
            ss = c.hsvSaturation
            vv = c.hsvValue
            if (anchorItem && parent) {
                var p = anchorItem.mapToItem(parent, 0, anchorItem.height + 4)
                x = Math.max(8, Math.min(parent.width - width - 8, p.x - width + anchorItem.width))
                y = Math.max(8, Math.min(parent.height - height - 8, p.y))
            } else if (parent) {
                x = Math.max(8, (parent.width - width) * 0.5)
                y = Math.max(8, (parent.height - height) * 0.5)
            }
            open()
        }

        function pushLive() {
            if (!visible)
                return
            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
            if (e)
                e.applyField(field, _buttonMap._toHex(live))
        }

        onHhChanged: pushLive()
        onSsChanged: pushLive()
        onVvChanged: pushLive()

        ColumnLayout {
            anchors.fill: parent
            spacing: 8
            Label {
                text: "Pick color"
                color: "#E4E4E7"
                font.bold: true
            }
            Item {
                id: _sv
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#FFFFFF" }
                        GradientStop { position: 1; color: Qt.hsva(_colorPop.hh, 1, 1, 1) }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: 1; color: "#FF000000" }
                    }
                }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "transparent"
                    border.color: "#FFFFFF"
                    border.width: 2
                    x: _colorPop.ss * _sv.width - 6
                    y: (1 - _colorPop.vv) * _sv.height - 6
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 4
                        color: "transparent"
                        border.color: "#111111"
                        border.width: 1
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function take(mx, my) {
                        _colorPop.ss = Math.max(0, Math.min(1, mx / Math.max(1, _sv.width)))
                        _colorPop.vv = Math.max(0, Math.min(1, 1 - my / Math.max(1, _sv.height)))
                    }
                    onPressed: (m) => take(m.x, m.y)
                    onPositionChanged: (m) => { if (pressed) take(m.x, m.y) }
                }
            }
            Item {
                id: _hue
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#FF0000" }
                        GradientStop { position: 0.17; color: "#FFFF00" }
                        GradientStop { position: 0.33; color: "#00FF00" }
                        GradientStop { position: 0.50; color: "#00FFFF" }
                        GradientStop { position: 0.67; color: "#0000FF" }
                        GradientStop { position: 0.83; color: "#FF00FF" }
                        GradientStop { position: 1.0; color: "#FF0000" }
                    }
                }
                Rectangle {
                    width: 6
                    height: parent.height + 4
                    y: -2
                    x: _colorPop.hh * _hue.width - 3
                    radius: 2
                    color: "transparent"
                    border.color: "#FFFFFF"
                    border.width: 2
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function take(mx) {
                        _colorPop.hh = Math.max(0, Math.min(1, mx / Math.max(1, _hue.width)))
                    }
                    onPressed: (m) => take(m.x)
                    onPositionChanged: (m) => { if (pressed) take(m.x) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    width: 36
                    height: 24
                    radius: 4
                    color: _colorPop.live
                    border.color: "#52525B"
                }
                Label {
                    Layout.fillWidth: true
                    text: _buttonMap._toHex(_colorPop.live)
                    color: "#E4E4E7"
                    font.family: "Consolas"
                    font.pixelSize: 13
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: ["#18181B", "#3F3F46", "#E4E4E7", "#14532D", "#22C55E", "#BBF7D0", "#1D4ED8", "#7C2D12", "#831843", "#0F766E", "#FBBF24", "#000000", "#FFFFFF", "#7F1D1D"]
                    Rectangle {
                        required property string modelData
                        width: 16
                        height: 16
                        radius: 3
                        color: modelData
                        border.color: "#52525B"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var c = Qt.color(modelData)
                                _colorPop.hh = c.hsvHue < 0 ? 0 : c.hsvHue
                                _colorPop.ss = c.hsvSaturation
                                _colorPop.vv = c.hsvValue
                            }
                        }
                    }
                }
            }
        }
    }
}
