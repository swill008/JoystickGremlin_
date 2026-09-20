// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Device
import Gremlin.Style
import "helpers.js" as Helpers

Item {
    id: _page

    property var model: null
    property string pinSlug: ""
    property bool hoverPeek: true
    property var _liveCards: []
    property var slotSnap: []

    property string dragSlug: ""
    property string dragDir: ""
    property string dragName: ""
    property string dragPhoto: ""
    property string insertBefore: ""
    property string homeBefore: ""
    property string dragStackSlug: ""
    property string stackCandidate: ""
    property int ghostW: 280
    property int ghostH: 240
    property int pendingStackW: 0
    property int pendingStackH: 0
    property real dragOriginX: 0
    property real dragOriginY: 0
    property real stackTravel: 120
    property real insertTravel: 48
    property real floatX: 0
    property real floatY: 0
    property real grabOffX: 0
    property real grabOffY: 0
    property bool gotGrab: false

    signal focusSlug(string slug)
    signal openConfiguration(var card)
    signal configureModule(var card)
    signal pinControlDisplay(var card)
    signal autoMap(var card)
    signal openDeviceViewer(var card)
    signal openPairing(var card)
    signal openCalibration(var card)
    signal openDeviceInformation(var card)
    signal assignHardware(var card)
    signal ignoreDevice(var card)

    property int pileRev: 0

    function pack(m) {
        return {
            slug: m.slug,
            name: m.cardName || m.name,
            rawName: m.rawName,
            guid: m.guid,
            direction: m.direction,
            status: m.status,
            bus: m.bus,
            tab: m.tab,
            isStub: m.isStub,
            isModule: m.isModule
        }
    }

    function registerCard(card) {
        _liveCards.push(card)
    }

    function unregisterCard(card) {
        _liveCards = _liveCards.filter(function(item) { return item !== card })
    }

    function paneDir(card) {
        if (_page.model && _page.model.splitMode !== "none")
            return card.direction
        return ""
    }

    function cardOnPage(card) {
        if (!card || !card.slug)
            return false
        if (card.width < 32 || card.height < 32)
            return false
        var p = card
        while (p) {
            if (p.visible === false)
                return false
            p = p.parent
        }
        return true
    }

    function cardBySlug(slug) {
        for (var i = 0; i < _liveCards.length; ++i) {
            var card = _liveCards[i]
            if (card && card.slug === slug && cardOnPage(card))
                return card
        }
        return null
    }

    function snapshotSlots(dragged, dir, dragCard) {
        var list = []
        if (!model)
            return
        var leaders = model.pileLeaders(dir)
        var dleft = 0
        var dw = ghostW
        if (dragCard) {
            var dpos = dragCard.mapToItem(_page, 0, 0)
            dleft = dpos.x
            dw = dragCard.width
        }
        var skip = dragged
        for (var k = 0; k < leaders.length; ++k) {
            var mem = model.pileMembers(leaders[k])
            for (var m = 0; m < mem.length; ++m) {
                if (mem[m] === dragged)
                    skip = leaders[k]
            }
        }
        for (var i = 0; i < leaders.length; ++i) {
            var s = leaders[i]
            if (s === skip)
                continue
            var card = cardBySlug(s)
            if (!card)
                continue
            var o = card.mapToItem(_page, 0, 0)
            var left = o.x
            if (left > dleft)
                left -= dw + 16
            list.push({
                slug: s,
                left: left,
                mid: left + card.width / 2,
                top: o.y,
                y: o.y + card.height / 2,
                w: card.width,
                h: card.height
            })
        }
        slotSnap = list
    }

    function pickInsertFromSnap(gx, gy) {
        var slots = slotSnap
        if (!slots || !slots.length)
            return insertBefore
        var hit = false
        var before = ""
        for (var j = 0; j < slots.length; ++j) {
            var s = slots[j]
            var sameRow = Math.abs(gy - s.y) < Math.max(120, s.h * 0.75)
            if (!sameRow)
                continue
            hit = true
            if (gx <= s.mid) {
                before = s.slug
                break
            }
        }
        if (!hit)
            return insertBefore
        return before
    }

    function pickStackAt(slug, gx, gy) {
        if (!model || !slug)
            return ""
        var dir = dragDir
        var homePile = {}
        var members = model.pileMembers(slug)
        for (var mi = 0; mi < members.length; ++mi)
            homePile[members[mi]] = true
        var best = null
        var bestArea = 0
        var bestC = 1e12
        var fw = ghostW
        var fh = ghostH
        var fx = gx - fw / 2
        var fy = gy - fh / 2
        for (var i = 0; i < _liveCards.length; ++i) {
            var other = _liveCards[i]
            if (!cardOnPage(other) || other.slug === slug)
                continue
            if (dir && other.direction !== dragDir && dragDir.length)
                continue
            var origin = other.mapToItem(_page, 0, 0)
            var cx = origin.x + other.width / 2
            var cy = origin.y + other.height / 2
            var ox = Math.min(fx + fw, origin.x + other.width) - Math.max(fx, origin.x)
            var oy = Math.min(fy + fh, origin.y + other.height) - Math.max(fy, origin.y)
            var area = (ox > 0 && oy > 0) ? ox * oy : 0
            var cdist = Math.sqrt((gx - cx) * (gx - cx) + (gy - cy) * (gy - cy))
            if (area > bestArea) {
                bestArea = area
                best = other
                bestC = cdist
            }
        }
        var dx = gx - dragOriginX
        var dy = gy - dragOriginY
        var traveled = Math.sqrt(dx * dx + dy * dy)
        var heavy = fw * fh * 0.55
        var close = Math.min(fw, fh) * 0.22
        if (traveled >= stackTravel && best && !homePile[best.slug] && bestArea >= heavy && bestC < close) {
            pendingStackW = Math.round(best.width)
            pendingStackH = Math.round(best.height)
            return best.slug
        }
        pendingStackW = 0
        pendingStackH = 0
        return ""
    }

    function nextLeader(slug, dir) {
        if (!model)
            return ""
        var list = model.pileLeaders(dir)
        for (var i = 0; i < list.length; ++i) {
            if (list[i] === slug)
                return (i + 1 < list.length) ? list[i + 1] : ""
            var mem = model.pileMembers(list[i])
            for (var j = 0; j < mem.length; ++j) {
                if (mem[j] === slug)
                    return (i + 1 < list.length) ? list[i + 1] : ""
            }
        }
        return ""
    }

    function noteStackHover(candidate) {
        if (candidate === stackCandidate)
            return
        stackCandidate = candidate
        if (dragStackSlug !== "")
            dragStackSlug = ""
        _stackDwell.stop()
        if (candidate.length)
            _stackDwell.restart()
    }

    function beginDrag(card) {
        if (!card || !card.slug)
            return
        var origin = card.mapToItem(_page, 0, 0)
        var mid = card.mapToItem(_page, card.width / 2, card.height / 2)
        dragOriginX = mid.x
        dragOriginY = mid.y
        stackTravel = Math.max(110, Math.min(card.width, card.height) * 0.5)
        dragDir = paneDir(card)
        dragName = card.cardName || ""
        dragPhoto = card.photo || ""
        ghostW = Math.round(card.width)
        ghostH = Math.round(card.height)
        floatX = origin.x
        floatY = origin.y
        gotGrab = false
        grabOffX = 0
        grabOffY = 0
        dragStackSlug = ""
        stackCandidate = ""
        pendingStackW = 0
        pendingStackH = 0
        snapshotSlots(card.slug, dragDir, card)
        homeBefore = nextLeader(card.slug, dragDir)
        insertBefore = homeBefore
        dragSlug = card.slug
        _stackDwell.stop()
    }

    function updateDragAt(sx, sy) {
        if (!dragSlug)
            return
        var p = _page.mapFromItem(null, sx, sy)
        if (!gotGrab) {
            grabOffX = p.x - floatX
            grabOffY = p.y - floatY
            gotGrab = true
        }
        floatX = p.x - grabOffX
        floatY = p.y - grabOffY
        var gx = floatX + ghostW / 2
        var gy = floatY + ghostH / 2
        var dx = gx - dragOriginX
        var dy = gy - dragOriginY
        var traveled = Math.sqrt(dx * dx + dy * dy)
        noteStackHover(pickStackAt(dragSlug, gx, gy))
        if (dragStackSlug.length)
            return
        if (traveled < insertTravel)
            return
        var before = pickInsertFromSnap(gx, gy)
        if (insertBefore !== before)
            insertBefore = before
    }

    function clearDrag() {
        _stackDwell.stop()
        dragSlug = ""
        dragDir = ""
        dragName = ""
        dragPhoto = ""
        insertBefore = ""
        homeBefore = ""
        dragStackSlug = ""
        stackCandidate = ""
        pendingStackW = 0
        pendingStackH = 0
        gotGrab = false
        slotSnap = []
    }

    function handleDrop(slug) {
        if (!model || !slug) {
            clearDrag()
            return
        }
        var stackTo = dragStackSlug
        var before = insertBefore
        var home = homeBefore
        var stackW = pendingStackW
        var stackH = pendingStackH
        clearDrag()
        if (stackTo) {
            model.stackSlugs(slug, stackTo)
            if (stackW > 0 && stackH > 0)
                model.setPileSize(stackTo, stackW, stackH)
            return
        }
        if (before === home)
            return
        model.unstackSlug(slug)
        model.moveSlugBefore(slug, before)
    }

    function bindCard(card) {
        card.hoverPeek = _page.hoverPeek
        card.pinActive = _page.pinSlug === card.slug
        card.onCardFocused.connect(function() {
            if (model)
                model.raiseSlug(card.slug)
            _page.focusSlug(card.slug)
        })
        card.onOpenConfiguration.connect(function() { _page.openConfiguration(_page.pack(card)) })
        card.onConfigureModule.connect(function() { _page.configureModule(_page.pack(card)) })
        card.onPinControlDisplay.connect(function() { _page.pinControlDisplay(_page.pack(card)) })
        card.onAutoMap.connect(function() { _page.autoMap(_page.pack(card)) })
        card.onOpenDeviceViewer.connect(function() { _page.openDeviceViewer(_page.pack(card)) })
        card.onOpenPairing.connect(function() { _page.openPairing(_page.pack(card)) })
        card.onOpenCalibration.connect(function() { _page.openCalibration(_page.pack(card)) })
        card.onOpenDeviceInformation.connect(function() { _page.openDeviceInformation(_page.pack(card)) })
        card.onAssignHardware.connect(function() { _page.assignHardware(_page.pack(card)) })
        card.onIgnoreDevice.connect(function() { _page.ignoreDevice(_page.pack(card)) })
        card.dragStarted.connect(function() { _page.beginDrag(card) })
        card.dragMovedAt.connect(function(sx, sy) { _page.updateDragAt(sx, sy) })
        card.dropAt.connect(function() { _page.handleDrop(card.slug) })
        card.onSizeChanged.connect(function(w, h) {
            if (model)
                model.setPileSize(card.slug, w, h)
        })
        card.onResetSize.connect(function() {
            if (model)
                model.resetCardSize(card.slug)
        })
        card.onClearSettings.connect(function() {
            if (model)
                model.clearCardSettings(card.slug)
        })
        card.onUnstackCard.connect(function() {
            if (model)
                model.unstackSlug(card.slug)
        })
        card.onUnstackAllCards.connect(function() {
            if (model)
                model.unstackAll(card.slug)
        })
        card.Component.onDestruction.connect(function() { _page.unregisterCard(card) })
        _page.registerCard(card)
    }

    function refreshCards() {
        for (var i = 0; i < _liveCards.length; ++i) {
            var card = _liveCards[i]
            if (card && card.slug)
                fillCard(card, card.slug)
        }
    }

    function fillCard(card, slug) {
        if (!model)
            return
        var info = model.cardMap(slug)
        card.slug = info.slug || slug
        card.cardName = info.name || ""
        card.rawName = info.rawName || ""
        card.guid = info.guid || ""
        card.direction = info.direction || "source"
        card.status = info.status || ""
        card.bus = info.bus || ""
        card.buttons = info.buttons || 0
        card.axes = info.axes || 0
        card.hats = info.hats || 0
        if (card.photo !== (info.photo || ""))
            card.photo = info.photo || ""
        card.isStub = !!info.isStub
        card.isModule = !!info.isModule
        card.tab = info.tab || "physical"
        card.target = info.target || ""
        card.lastLine = info.lastLine || ""
        card.lastHardware = info.lastHardware || ""
        card.focused = !!info.focused
        card.pinActive = _page.pinSlug === card.slug
    }

    Timer {
        id: _stackDwell
        interval: 1500
        repeat: false
        onTriggered: {
            if (!_page.dragSlug.length || !_page.stackCandidate.length)
                return
            _page.dragStackSlug = _page.stackCandidate
            _page.insertBefore = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Status"
                color: "#E4E4E7"
                font.pixelSize: 13
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Label { text: "Split"; color: "#A1A1AA"; font.pixelSize: 11 }
            ComboBox {
                id: _split
                model: ["None", "Vertical", "Horizontal"]
                implicitWidth: 140
                currentIndex: {
                    var mode = _page.model ? _page.model.splitMode : "none"
                    if (mode === "vertical") return 1
                    if (mode === "horizontal") return 2
                    return 0
                }
                onActivated: {
                    if (!_page.model)
                        return
                    _page.model.setSplitMode(["none", "vertical", "horizontal"][currentIndex])
                }
            }
        }

        SplitView {
            id: _splitView
            Layout.fillWidth: true
            Layout.fillHeight: visible
            visible: _page.model && _page.model.splitMode !== "none"
            orientation: (_page.model && _page.model.splitMode === "horizontal") ? Qt.Vertical : Qt.Horizontal
            handle: Rectangle { implicitWidth: 8; implicitHeight: 8; color: "#52525B" }

            property bool applying: false

            function applyRatio() {
                if (!_page.model || width < 8 || height < 8)
                    return
                applying = true
                var r = _page.model.splitRatio
                if (!(r > 0))
                    r = 0.5
                if (orientation === Qt.Horizontal)
                    _inputPane.SplitView.preferredWidth = Math.round(width * r)
                else
                    _inputPane.SplitView.preferredHeight = Math.round(height * r)
                applying = false
            }

            function saveRatio() {
                if (applying || !_page.model || width < 8 || height < 8)
                    return
                var r = orientation === Qt.Horizontal ? (_inputPane.width / width) : (_inputPane.height / height)
                if (!(r > 0))
                    return
                _page.model.setSplitRatio(r)
            }

            Timer {
                id: _ratioSave
                interval: 150
                onTriggered: _splitView.saveRatio()
            }

            onWidthChanged: applyRatio()
            onHeightChanged: applyRatio()
            onVisibleChanged: {
                if (visible)
                    Qt.callLater(applyRatio)
                else
                    saveRatio()
            }
            onResizingChanged: if (!resizing) saveRatio()

            StatusPane {
                id: _inputPane
                SplitView.minimumWidth: 180
                SplitView.minimumHeight: 120
                title: "Input modules"
                direction: "source"
                onWidthChanged: if (_splitView.visible && !_splitView.applying) _ratioSave.restart()
                onHeightChanged: if (_splitView.visible && !_splitView.applying) _ratioSave.restart()
            }
            StatusPane {
                SplitView.minimumWidth: 180
                SplitView.minimumHeight: 120
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                title: "Output modules"
                direction: "dest"
            }
        }

        StatusPane {
            Layout.fillWidth: true
            Layout.fillHeight: visible
            visible: !_page.model || _page.model.splitMode === "none"
            title: ""
            direction: ""
        }
    }

    component SlotGhost: Rectangle {
        radius: 4
        color: "#3318181B"
        border.width: 2
        border.color: "#A1A1AA"

        Image {
            anchors.fill: parent
            anchors.margins: 10
            source: _page.dragPhoto
            fillMode: Image.PreserveAspectFit
            opacity: 0.4
            visible: _page.dragPhoto && _page.dragPhoto.length
            asynchronous: true
            cache: true
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: _page.dragName
            color: "#E4E4E7"
            font.pixelSize: 13
            font.bold: true
            opacity: 0.8
        }
    }

    component StatusPane: Item {
        id: _pane
        property string title: ""
        property string direction: ""
        property int dragLocks: 0
        property bool paneActive: {
            var mode = _page.model ? _page.model.splitMode : "none"
            if (!_pane.direction.length)
                return mode === "none"
            return mode !== "none"
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            Label {
                visible: _pane.title.length
                text: _pane.title
                color: "#A1A1AA"
                font.pixelSize: 11
                font.capitalization: Font.AllUppercase
            }

            Flickable {
                id: _flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: _flow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: _pane.dragLocks === 0
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Flow {
                    id: _flow
                    width: _flick.width
                    spacing: 16

                    Repeater {
                        id: _piles
                        model: {
                            _page.pileRev
                            if (!_pane.paneActive)
                                return []
                            return _page.model ? _page.model.pileLeaders(_pane.direction) : []
                        }

                        delegate: Item {
                            id: _pile
                            property var members: _page.model ? _page.model.pileMembers(modelData) : [modelData]
                            property int extra: Math.max(0, members.length - 1) * 14
                            property bool dragging: false
                            property bool isDragHome: _page.dragSlug === modelData && members.length === 1
                            property bool showGhost: {
                                if (!_page.dragSlug.length || _page.dragStackSlug.length)
                                    return false
                                if (_pane.direction.length && _page.dragDir !== _pane.direction)
                                    return false
                                return _page.insertBefore === modelData
                            }
                            property int cardW: {
                                _page.pileRev
                                var saved = _page.model ? _page.model.cardWidth(modelData) : 0
                                if (saved >= 220)
                                    return saved
                                var avail = _flow.width
                                var cols = Math.max(1, Math.floor((avail + 16) / 332))
                                return Math.min(420, Math.max(260, Math.floor((avail - (cols - 1) * 16) / cols)))
                            }
                            property int cardH: {
                                _page.pileRev
                                var saved = _page.model ? _page.model.cardHeight(modelData) : 0
                                return saved >= 140 ? saved : 0
                            }
                            property int ghostPad: showGhost ? _page.ghostW + 16 : 0

                            width: isDragHome ? 0 : (cardW + extra + ghostPad)
                            height: {
                                if (isDragHome)
                                    return Math.max(1, _page.ghostH)
                                var h = cardH >= 140 ? cardH + extra : Math.max(120, childrenRect.height)
                                return Math.max(h, showGhost ? _page.ghostH : 0)
                            }
                            z: dragging || isDragHome ? 10000 : 0
                            clip: false

                            function freezeSlot() {
                                dragging = true
                                _pane.dragLocks += 1
                            }

                            function thawSlot() {
                                if (!dragging)
                                    return
                                dragging = false
                                _pane.dragLocks = Math.max(0, _pane.dragLocks - 1)
                            }

                            SlotGhost {
                                visible: _pile.showGhost
                                x: 0
                                y: 0
                                width: _page.ghostW
                                height: _page.ghostH
                            }

                            Repeater {
                                model: _pile.members
                                delegate: StatusCard {
                                    id: _card
                                    x: index * 14 + _pile.ghostPad
                                    y: index * 14
                                    stackIndex: index
                                    stacked: _pile.members.length > 1
                                    width: _pile.cardW
                                    height: _pile.cardH > 0 ? _pile.cardH : implicitHeight
                                    dropStacking: _page.dragStackSlug === slug
                                    opacity: (_page.dragSlug === modelData || _page.dragSlug === slug) ? 0 : 1
                                    onLiftingChanged: {
                                        if (lifting)
                                            _pile.freezeSlot()
                                        else
                                            _pile.thawSlot()
                                    }
                                    Component.onCompleted: {
                                        _page.fillCard(_card, modelData)
                                        _page.bindCard(_card)
                                    }
                                }
                            }
                        }
                    }

                    SlotGhost {
                        visible: _pane.paneActive && _page.dragSlug.length && !_page.dragStackSlug.length && _page.insertBefore === "" && (!_pane.direction.length || _page.dragDir === _pane.direction)
                        width: visible ? _page.ghostW : 0
                        height: _page.ghostH
                    }
                }
            }
        }
    }

    Item {
        id: _float
        visible: _page.dragSlug.length > 0
        z: 100000
        x: _page.floatX
        y: _page.floatY
        width: _page.ghostW
        height: _page.ghostH

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "#18181B"
            border.width: 2
            border.color: _page.dragStackSlug.length ? "#22C55E" : "#E4E4E7"

            Image {
                anchors.fill: parent
                anchors.margins: 10
                source: _page.dragPhoto
                fillMode: Image.PreserveAspectFit
                visible: _page.dragPhoto && _page.dragPhoto.length
                asynchronous: true
                cache: true
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: _page.dragName
                color: "#E4E4E7"
                font.pixelSize: 13
                font.bold: true
            }
        }
    }

    Connections {
        target: model
        function onPanesChanged() {
            _page.pileRev++
            if (_splitView.visible)
                Qt.callLater(_splitView.applyRatio)
        }
        function onClaimsChanged() {
            Qt.callLater(_page.refreshCards)
        }
        function onLastChanged() {
            Qt.callLater(_page.refreshCards)
        }
    }

    Label {
        anchors.centerIn: parent
        visible: model && model.visibleCount() === 0
        text: "No devices to show. Plug in hardware or unhide a card from View → Hidden devices…"
        color: "#A1A1AA"
    }
}
