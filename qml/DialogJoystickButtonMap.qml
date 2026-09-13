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
    onEditingChanged: if (editing) Qt.callLater(refreshReservoir)
    property var liveNodes: []
    property var workNodes: []
    property string photoOverride: ""
    property string storedImage: ""
    property string liveImage: ""
    property string selectedId: ""
    property var selectedNode: null
    property bool _allowClose: false
    property var resItems: []
    property int resTick: 0
    property string poolFilter: ""
    onPoolFilterChanged: refreshReservoir()
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
    property string poolKind: "btn"
    property int poolHw: 0
    property string poolName: ""
    property real poolX: 0
    property real poolY: 0

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
        liveImage = doc.image && doc.image.length ? doc.image : stockImage
        applyImage(liveImage)
        return true
    }

    function enterEdit() {
        loadLive()
        workNodes = JSON.parse(JSON.stringify(liveNodes || []))
        applyImage(liveImage.length ? liveImage : stockImage)
        editing = true
        selectedId = ""
        selectedNode = null
        Qt.callLater(function() {
            refreshReservoir()
            clampPool()
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
            nodes: nodes
        }
        if (_hw.save(targetName, JSON.stringify(doc))) {
            liveNodes = JSON.parse(JSON.stringify(nodes))
            liveImage = image
            applyImage(liveImage)
            editing = false
            workNodes = []
            selectedId = ""
            selectedNode = null
        }
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

    function applySelected() {
        var n = currentNode()
        selectedNode = n
        selectedId = n ? n.id : ""
    }

    Component.onCompleted: {
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

    function refreshReservoir() {
        var e = _ed()
        var all = e ? e.catalog() : []
        var q = (poolFilter || "").trim().toLowerCase()
        var u = []
        for (var i = 0; i < all.length; i++) {
            var row = all[i]
            if (row.placed)
                continue
            if (q.length) {
                var hay = ((row.friendly || "") + " " + (row.fullName || "") + " " + (row.kind || "") + " " + String(row.hwId)).toLowerCase()
                if (hay.indexOf(q) < 0)
                    continue
            }
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
        if (!ed)
            return
        if (_poolFloat && _poolFloat.visible) {
            var lp = _poolFloat.mapFromItem(_buttonMap.contentItem, vx, vy)
            if (lp.x >= 0 && lp.y >= 0 && lp.x <= _poolFloat.width && lp.y <= _poolFloat.height)
                return
        }
        var local = ed.mapFromItem(_buttonMap.contentItem, vx, vy)
        if (local.x < 0 || local.y < 0 || local.x > ed.width || local.y > ed.height)
            return
        ed.addChiplet(kind, hw, local.x, local.y)
        refreshReservoir()
    }

    function resetLayout() {
        workNodes = []
        var e = _ed()
        if (e)
            e.clearLayout()
        selectedId = ""
        selectedNode = null
        Qt.callLater(refreshReservoir)
    }

    function nodeIsGroup(n) {
        return !!(n && (n.kind === "plus" || n.kind === "pair" || n.kind === "axis_stack" || n.kind === "stack" || (n.members && n.members.length)))
    }

    function openChipMenu(x, y) {
        applySelected()
        if (!selectedNode)
            return
        var e = _ed()
        var p = e ? e.mapToItem(_buttonMap.contentItem, x, y) : Qt.point(x, y)
        if (_chipPop.width < 240)
            _chipPop.width = 280
        if (_chipPop.height < 200)
            _chipPop.height = 480
        var maxW = Math.max(240, _buttonMap.width - 16)
        var maxH = Math.max(200, _buttonMap.height - 16)
        if (_chipPop.width > maxW)
            _chipPop.width = maxW
        if (_chipPop.height > maxH)
            _chipPop.height = maxH
        _chipPop.x = Math.max(8, Math.min(p.x, _buttonMap.width - _chipPop.width - 8))
        _chipPop.y = Math.max(8, Math.min(p.y, _buttonMap.height - _chipPop.height - 8))
        _chipPop.open()
    }

    Menu {
        id: _groupMenu
        MenuItem { text: "Group selected"; onTriggered: { var e = _ed(); if (e) e.groupSelection() } }
        MenuItem { text: "Break group"; onTriggered: { var e = _ed(); if (e) e.ungroupSelection() } }
        MenuSeparator {}
        MenuItem { text: "Edit group"; onTriggered: { var e = _ed(); if (e) e.beginGroupEdit(e.selectedId) } }
        MenuItem { text: "Done editing group"; onTriggered: { var e = _ed(); if (e) e.endGroupEdit() } }
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
        MenuItem { text: "Delete extra leader"; onTriggered: { var e = _ed(); if (e) e.deleteLeader() } }
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolBar {
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Button {
                    text: editing ? "Editing" : "Edit"
                    enabled: !editing
                    onClicked: enterEdit()
                }
                MenuBar {
                    visible: editing
                    Menu {
                        title: "Menu"
                        Menu {
                            title: "Options"
                            Menu {
                                title: "Session"
                                MenuItem { text: "Save"; onTriggered: saveEdit() }
                                MenuItem { text: "Cancel"; onTriggered: cancelEdit() }
                                MenuSeparator {}
                                MenuItem { text: "Reset layout"; onTriggered: _resetDlg.open() }
                            }
                            Menu {
                                title: "Group"
                                MenuItem { text: "Group selected"; onTriggered: { var e = _ed(); if (e) e.groupSelection() } }
                                MenuItem { text: "Break group"; onTriggered: { var e = _ed(); if (e) e.ungroupSelection() } }
                                MenuSeparator {}
                                MenuItem { text: "Edit group"; onTriggered: { var e = _ed(); if (e) e.beginGroupEdit(e.selectedId) } }
                                MenuItem { text: "Done editing group"; onTriggered: { var e = _ed(); if (e) e.endGroupEdit() } }
                                MenuSeparator {}
                                MenuItem { text: "Align left"; onTriggered: { var e = _ed(); if (e) e.setAlignH("left") } }
                                MenuItem { text: "Align center"; onTriggered: { var e = _ed(); if (e) e.setAlignH("center") } }
                                MenuItem { text: "Align right"; onTriggered: { var e = _ed(); if (e) e.setAlignH("right") } }
                                MenuItem { text: "Free layout"; onTriggered: { var e = _ed(); if (e) e.setAlignH("free") } }
                            }
                            Menu {
                                title: "Leader"
                                MenuItem { text: "Add straight spine"; onTriggered: { var e = _ed(); if (e && selectedNode) { e.ensureMidSpine(selectedNode); e.bump() } } }
                                MenuItem { text: "Add curved spine"; onTriggered: { var e = _ed(); if (e && selectedNode) e.addCurveSpine(selectedNode) } }
                                MenuItem { text: "This segment curved"; onTriggered: { var e = _ed(); if (e) e.setSegCurve(e.currentLeader(e.nodeAt(e.selectedId)), Math.max(0, e.selectedSeg), true) } }
                                MenuItem { text: "This segment straight"; onTriggered: { var e = _ed(); if (e) e.setSegCurve(e.currentLeader(e.nodeAt(e.selectedId)), Math.max(0, e.selectedSeg), false) } }
                                MenuItem { text: "All segments curved"; onTriggered: { var e = _ed(); if (e) e.setAllSegCurve(true) } }
                                MenuItem { text: "All segments straight"; onTriggered: { var e = _ed(); if (e) e.setAllSegCurve(false) } }
                                MenuSeparator {}
                                MenuItem { text: "Add leader (same chip / hotspot)"; onTriggered: { var e = _ed(); if (e) e.addLeader() } }
                                MenuItem { text: "Branch from this end"; onTriggered: { var e = _ed(); if (e) e.addBranch() } }
                                MenuItem { text: "Delete extra leader"; onTriggered: { var e = _ed(); if (e) e.deleteLeader() } }
                                MenuSeparator {}
                                MenuItem { text: "Detach chip end"; onTriggered: { var e = _ed(); if (e) e.detachEnd("from") } }
                                MenuItem { text: "Detach hotspot end"; onTriggered: { var e = _ed(); if (e) e.detachEnd("to") } }
                                MenuItem { text: "Reconnect to this chip"; onTriggered: { var e = _ed(); if (e) e.attachEndToSelf("from") } }
                                MenuItem { text: "Reconnect to this hotspot"; onTriggered: { var e = _ed(); if (e) e.attachEndToSelf("to") } }
                                MenuItem { text: "Delete selected spine"; onTriggered: { var e = _ed(); if (e) e.deleteSelection() } }
                            }
                            Menu {
                                title: "Image"
                                MenuItem { text: "Choose background…"; onTriggered: _imageDialog.open() }
                                MenuItem {
                                    text: "Clear image"
                                    onTriggered: {
                                        _hw.clearImage(targetName)
                                        applyImage(stockImage)
                                    }
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
                            }
                            Menu {
                                title: "Grid"
                                MenuItem {
                                    text: "Show grid"
                                    checkable: true
                                    checked: {
                                        var e = _ed()
                                        return e ? e.gridOn : true
                                    }
                                    onTriggered: {
                                        var e = _ed()
                                        if (e)
                                            e.gridOn = checked
                                    }
                                }
                                MenuItem {
                                    text: "Snap to grid"
                                    checkable: true
                                    checked: {
                                        var e = _ed()
                                        return e ? e.snapOn : true
                                    }
                                    onTriggered: {
                                        var e = _ed()
                                        if (e)
                                            e.snapOn = checked
                                    }
                                }
                                MenuItem {
                                    text: "Auto pan"
                                    checkable: true
                                    checked: {
                                        var c = _cardLoader.item
                                        return c ? c.autoPanOn === true : false
                                    }
                                    onTriggered: {
                                        var c = _cardLoader.item
                                        if (c)
                                            c.autoPanOn = checked
                                    }
                                }
                                MenuSeparator {}
                                Menu {
                                    title: "Size"
                                    MenuItem {
                                        text: "4"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 4 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 4 }
                                    }
                                    MenuItem {
                                        text: "8"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 8 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 8 }
                                    }
                                    MenuItem {
                                        text: "12"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 12 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 12 }
                                    }
                                    MenuItem {
                                        text: "16"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 16 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 16 }
                                    }
                                    MenuItem {
                                        text: "24"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 24 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 24 }
                                    }
                                    MenuItem {
                                        text: "32"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 32 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 32 }
                                    }
                                    MenuItem {
                                        text: "48"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 48 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 48 }
                                    }
                                    MenuItem {
                                        text: "64"
                                        checkable: true
                                        checked: { var e = _ed(); return e && e.gridSize === 64 }
                                        onTriggered: { var e = _ed(); if (e) e.gridSize = 64 }
                                    }
                                }
                            }
                        }
                    }
                }
                Label {
                    visible: editing
                    text: _cardLoader.item ? (Math.round(_cardLoader.item.zoom * 100) + "%") : "100%"
                    color: "#E4E4E7"
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
                        }
                    }
                }

                QtObject {
                    id: _cardLoader
                    property var item: null
                }

                MouseArea {
                    id: _poolFloat
                    visible: editing
                    z: 30
                    x: 12
                    width: 280
                    height: 160
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    preventStealing: false
                    onPressed: (m) => { m.accepted = true }
                    onClicked: (m) => { m.accepted = true }
                    onDoubleClicked: (m) => { m.accepted = true }
                    onWheel: (w) => { w.accepted = true }
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

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "#CC0C0C0E"
                        border.color: "#3F3F46"
                    }
                    ColumnLayout {
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
                                    placeholderText: "Filter"
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
                                        opacity: (poolDrag && poolHw === (modelData ? modelData.hwId : -1) && poolKind === (modelData ? modelData.kind : "")) ? 0.35 : 1
                                        Text {
                                            id: _chipLab
                                            anchors.centerIn: parent
                                            text: modelData ? modelData.friendly : ""
                                            color: lit ? "#BBF7D0" : "#E4E4E7"
                                            font.pixelSize: 11
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.OpenHandCursor
                                            onPressed: (m) => {
                                                if (!modelData)
                                                    return
                                                poolKind = modelData.kind
                                                poolHw = modelData.hwId
                                                poolName = modelData.friendly
                                                poolDrag = true
                                                var p = mapToItem(_buttonMap.contentItem, m.x, m.y)
                                                poolX = p.x
                                                poolY = p.y
                                            }
                                            onPositionChanged: (m) => {
                                                if (!poolDrag)
                                                    return
                                                var p = mapToItem(_buttonMap.contentItem, m.x, m.y)
                                                poolX = p.x
                                                poolY = p.y
                                            }
                                            onReleased: (m) => {
                                                if (!poolDrag)
                                                    return
                                                var p = mapToItem(_buttonMap.contentItem, m.x, m.y)
                                                dropPool(p.x, p.y)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PoolGrip { edge: "n"; height: 6; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; cursorShape: Qt.SizeVerCursor }
                    PoolGrip { edge: "s"; height: 6; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; cursorShape: Qt.SizeVerCursor }
                    PoolGrip { edge: "w"; width: 6; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; cursorShape: Qt.SizeHorCursor }
                    PoolGrip { edge: "e"; width: 6; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; cursorShape: Qt.SizeHorCursor }
                    PoolGrip { edge: "nw"; width: 12; height: 12; anchors.left: parent.left; anchors.top: parent.top; cursorShape: Qt.SizeFDiagCursor }
                    PoolGrip { edge: "ne"; width: 12; height: 12; anchors.right: parent.right; anchors.top: parent.top; cursorShape: Qt.SizeBDiagCursor }
                    PoolGrip { edge: "sw"; width: 12; height: 12; anchors.left: parent.left; anchors.bottom: parent.bottom; cursorShape: Qt.SizeBDiagCursor }
                    PoolGrip { edge: "se"; width: 14; height: 14; anchors.right: parent.right; anchors.bottom: parent.bottom; cursorShape: Qt.SizeFDiagCursor; z: 2 }

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
                    target: parent
                    function onWidthChanged() { if (editing) clampPool() }
                    function onHeightChanged() { if (editing) clampPool() }
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
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            anchors.bottomMargin: 14
            anchors.rightMargin: 12
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: selectedNode ? (selectedNode.friendly || selectedNode.id || "Chip") : "Chip"
                    font.bold: true
                    color: "#E4E4E7"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
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
                Button {
                    text: "×"
                    implicitWidth: 28
                    implicitHeight: 24
                    onClicked: _chipPop.close()
                }
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
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: _chipForm.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
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
                        Label { text: "Border"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.border ? selectedNode.border : "#3F3F46"; onPicked: _colorPop.openField("border", hex, this) }
                        Label { text: "Text"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.textColor ? selectedNode.textColor : "#E4E4E7"; onPicked: _colorPop.openField("textColor", hex, this) }
                        Label { text: "Highlight"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.hlColor ? selectedNode.hlColor : "#14532D"; onPicked: _colorPop.openField("hlColor", hex, this) }
                        Label { text: "HL border"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.hlBorder ? selectedNode.hlBorder : "#22C55E"; onPicked: _colorPop.openField("hlBorder", hex, this) }
                        Label { text: "HL text"; color: "#A1A1AA" }
                        ColorSwatch { hex: selectedNode && selectedNode.hlText ? selectedNode.hlText : "#BBF7D0"; onPicked: _colorPop.openField("hlText", hex, this) }
                    }
                    Button {
                        text: "Delete chip"
                        Layout.fillWidth: true
                        enabled: !nodeIsGroup(selectedNode)
                        onClicked: {
                            if (nodeIsGroup(selectedNode))
                                return
                            var e = _ed()
                            if (e) e.deleteSelection()
                            _chipPop.close()
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
        parent: _buttonMap.contentItem
        visible: poolDrag
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
