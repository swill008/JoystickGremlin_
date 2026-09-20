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

    property string dragSlug: ""
    property string dragDir: ""
    property string dragName: ""
    property string dragPhoto: ""
    property string insertBefore: ""
    property string dragStackSlug: ""
    property int ghostW: 280
    property int ghostH: 240

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

    function overlapArea(a, b) {
        var ap = a.mapToItem(_page, 0, 0)
        var bp = b.mapToItem(_page, 0, 0)
        var ox = Math.min(ap.x + a.width, bp.x + b.width) - Math.max(ap.x, bp.x)
        var oy = Math.min(ap.y + a.height, bp.y + b.height) - Math.max(ap.y, bp.y)
        if (ox <= 0 || oy <= 0)
            return 0
        return ox * oy
    }

    function paneDir(card) {
        if (_page.model && _page.model.splitMode !== "none")
            return card.direction
        return ""
    }

    function pickTarget(card) {
        var out = { stack: "", before: "" }
        if (!model || !card || !card.slug)
            return out
        var slug = card.slug
        var mid = card.mapToItem(_page, card.width / 2, card.height / 2)
        var gx = mid.x
        var gy = mid.y
        var best = null
        var bestArea = 0
        var bestC = 1e12
        var dir = paneDir(card)
        var leaders = {}
        var leaderList = model.pileLeaders(dir)
        for (var li = 0; li < leaderList.length; ++li)
            leaders[leaderList[li]] = true
        var slots = []
        for (var i = 0; i < _liveCards.length; ++i) {
            var other = _liveCards[i]
            if (!other || !other.slug || other.slug === slug)
                continue
            if (dir && other.direction !== card.direction)
                continue
            var origin = other.mapToItem(_page, 0, 0)
            var p = other.mapToItem(_page, other.width / 2, other.height / 2)
            if (leaders[other.slug]) {
                var left = origin.x
                if (insertBefore === other.slug && ghostW > 0 && !dragStackSlug)
                    left += ghostW + 16
                slots.push({
                    slug: other.slug,
                    x: left + Math.min(other.width, card.width) / 2,
                    y: p.y,
                    left: left,
                    top: origin.y,
                    w: other.width,
                    h: other.height
                })
            }
            var area = overlapArea(card, other)
            var cdist = Math.sqrt((gx - p.x) * (gx - p.x) + (gy - p.y) * (gy - p.y))
            if (area > bestArea) {
                bestArea = area
                best = other
                bestC = cdist
            }
        }
        var heavy = card.width * card.height * 0.45
        if (best && bestArea >= heavy && bestC < Math.min(card.width, card.height) * 0.35) {
            out.stack = best.slug
            return out
        }
        slots.sort(function(a, b) {
            if (Math.abs(a.y - b.y) < 48)
                return a.x - b.x
            return a.y - b.y
        })
        for (var j = 0; j < slots.length; ++j) {
            var sameRow = Math.abs(gy - slots[j].y) < Math.max(80, slots[j].h * 0.6)
            if (sameRow && gx < slots[j].x) {
                out.before = slots[j].slug
                break
            }
            if (!sameRow && gy < slots[j].top) {
                out.before = slots[j].slug
                break
            }
        }
        return out
    }

    function beginDrag(card) {
        if (!card || !card.slug)
            return
        dragSlug = card.slug
        dragDir = paneDir(card)
        dragName = card.cardName || ""
        dragPhoto = card.photo || ""
        ghostW = Math.round(card.width)
        ghostH = Math.round(card.height)
        insertBefore = ""
        dragStackSlug = ""
        updateDrag(card)
    }

    function updateDrag(card) {
        if (!dragSlug || !card)
            return
        var t = pickTarget(card)
        if (t.stack) {
            if (dragStackSlug !== t.stack)
                dragStackSlug = t.stack
            if (insertBefore !== "")
                insertBefore = ""
        } else {
            if (dragStackSlug !== "")
                dragStackSlug = ""
            if (insertBefore !== t.before)
                insertBefore = t.before
        }
    }

    function clearDrag() {
        dragSlug = ""
        dragDir = ""
        dragName = ""
        dragPhoto = ""
        insertBefore = ""
        dragStackSlug = ""
    }

    function handleDrop(slug, card) {
        if (!model || !slug || !card)
            return
        var t = pickTarget(card)
        clearDrag()
        if (t.stack) {
            model.stackSlugs(slug, t.stack)
            var target = null
            for (var i = 0; i < _liveCards.length; ++i) {
                if (_liveCards[i] && _liveCards[i].slug === t.stack) {
                    target = _liveCards[i]
                    break
                }
            }
            if (target)
                model.setPileSize(t.stack, Math.round(target.width), Math.round(target.height))
            return
        }
        model.unstackSlug(slug)
        model.moveSlugBefore(slug, t.before)
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
        card.dragMoved.connect(function() { _page.updateDrag(card) })
        card.dropAt.connect(function() { _page.handleDrop(card.slug, card) })
        card.dragEnded.connect(function() { _page.clearDrag() })
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
        card.dropStacking = _page.dragStackSlug === (info.slug || slug)
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
        id: _ghost
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

                            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

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
                        visible: _page.dragSlug.length && !_page.dragStackSlug.length && _page.insertBefore === "" && (!_pane.direction.length || _page.dragDir === _pane.direction)
                        width: visible ? _page.ghostW : 0
                        height: _page.ghostH
                    }
                }
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

    Connections {
        target: _page
        function onDragStackSlugChanged() {
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
