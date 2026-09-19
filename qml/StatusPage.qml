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

    function handleDrop(slug, card) {
        if (!model || !slug || !card)
            return
        var gx = card.mapToItem(_page, card.width / 2, card.height / 2).x
        var gy = card.mapToItem(_page, card.width / 2, card.height / 2).y
        var best = null
        var bestD = 1e12
        for (var i = 0; i < _liveCards.length; ++i) {
            var other = _liveCards[i]
            if (!other || other.slug === slug)
                continue
            var p = other.mapToItem(_page, other.width / 2, other.height / 2)
            var d = Math.sqrt((gx - p.x) * (gx - p.x) + (gy - p.y) * (gy - p.y))
            if (d < bestD) {
                bestD = d
                best = other
            }
        }
        if (best && bestD < 88) {
            model.stackSlugs(slug, best.slug)
            return
        }
        model.unstackSlug(slug)
        var leaders = model.pileLeaders("")
        var dest = leaders.length
        for (var j = 0; j < leaders.length; ++j) {
            if (leaders[j] === slug)
                dest = j
        }
        model.moveSlug(slug, dest)
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
            Layout.fillHeight: true
            orientation: (_page.model && _page.model.splitMode === "horizontal") ? Qt.Vertical : Qt.Horizontal
            handle: Rectangle { implicitWidth: 6; implicitHeight: 6; color: "#3F3F46" }

            StatusPane {
                SplitView.preferredWidth: _splitView.width * 0.55
                SplitView.preferredHeight: _splitView.height * 0.55
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                visible: !_page.model || _page.model.splitMode !== "none"
                title: "Input modules"
                direction: "source"
            }
            StatusPane {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                visible: !_page.model || _page.model.splitMode !== "none"
                title: "Output modules"
                direction: "dest"
            }
        }

        StatusPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                                    z: index
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
            _split.currentIndex = model.splitMode === "vertical" ? 1 : (model.splitMode === "horizontal" ? 2 : 0)
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
