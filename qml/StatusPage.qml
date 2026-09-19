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

    function handleDrop(slug, card) {
        if (!model || !slug || !card)
            return
        var gx = card.mapToItem(_page, card.width / 2, card.height / 2).x
        var gy = card.mapToItem(_page, card.width / 2, card.height / 2).y
        var best = null
        var bestArea = 0
        var slots = []
        for (var i = 0; i < _liveCards.length; ++i) {
            var other = _liveCards[i]
            if (!other || !other.slug || other.slug === slug)
                continue
            if (_page.model.splitMode !== "none" && other.direction !== card.direction)
                continue
            var p = other.mapToItem(_page, other.width / 2, other.height / 2)
            slots.push({ slug: other.slug, x: p.x, y: p.y })
            var area = overlapArea(card, other)
            if (area > bestArea) {
                bestArea = area
                best = other
            }
        }
        // Either direction: ~25% of this card overlapping another is a stack.
        var need = Math.max(80 * 80, card.width * card.height * 0.25)
        if (best && bestArea >= need) {
            model.stackSlugs(slug, best.slug)
            return
        }
        model.unstackSlug(slug)
        slots.sort(function(a, b) {
            if (Math.abs(a.y - b.y) < 48)
                return a.x - b.x
            return a.y - b.y
        })
        var before = ""
        for (var j = 0; j < slots.length; ++j) {
            var sameRow = Math.abs(gy - slots[j].y) < 80
            if (sameRow && gx < slots[j].x) {
                before = slots[j].slug
                break
            }
            if (!sameRow && gy < slots[j].y) {
                before = slots[j].slug
                break
            }
        }
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
        card.onDropAt.connect(function() { _page.handleDrop(card.slug, card) })
        card.Component.onDestruction.connect(function() { _page.unregisterCard(card) })
        _page.registerCard(card)
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

    component StatusPane: Item {
        id: _pane
        property string title: ""
        property string direction: ""

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
                            property int cardW: {
                                var avail = _flow.width
                                var cols = Math.max(1, Math.floor((avail + 16) / 332))
                                return Math.min(420, Math.max(260, Math.floor((avail - (cols - 1) * 16) / cols)))
                            }

                            width: Math.max(cardW, childrenRect.width)
                            height: Math.max(120, childrenRect.height)

                            Repeater {
                                model: _pile.members
                                delegate: StatusCard {
                                    id: _card
                                    x: index * 14
                                    y: index * 14
                                    stackIndex: index
                                    width: _pile.cardW
                                    Component.onCompleted: {
                                        _page.fillCard(_card, modelData)
                                        _page.bindCard(_card)
                                    }
                                }
                            }
                        }
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
        function onModelReset() {}
    }

    Label {
        anchors.centerIn: parent
        visible: model && model.visibleCount() === 0
        text: "No devices to show. Plug in hardware or unhide a card from View → Hidden devices…"
        color: "#A1A1AA"
    }
}
