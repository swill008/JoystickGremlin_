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

    property alias model: _repeater.model
    property string pinSlug: ""
    property bool hoverPeek: true

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

    function placeSlug(slug, cx, cy) {
        var best = 0
        var bestD = 1e12
        for (var i = 0; i < _repeater.count; ++i) {
            var item = _repeater.itemAt(i)
            if (!item)
                continue
            var dx = cx - (item.x + item.width / 2)
            var dy = cy - (item.y + item.height / 2)
            var d = Math.sqrt(dx * dx + dy * dy)
            if (d < bestD) {
                bestD = d
                best = i
            }
        }
        if (model && model.moveSlug)
            model.moveSlug(slug, best)
    }

    function pack(m) {
        return {
            slug: m.slug,
            name: m.name,
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

    Flickable {
        id: _flick
        anchors.fill: parent
        anchors.margins: 16
        clip: true
        contentWidth: width
        contentHeight: _flow.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Flow {
            id: _flow
            width: _flick.width
            spacing: 12

            Repeater {
                id: _repeater

                delegate: StatusCard {
                    slug: model.slug
                    cardName: model.name
                    rawName: model.rawName
                    guid: model.guid
                    direction: model.direction
                    status: model.status
                    bus: model.bus
                    buttons: model.buttons
                    axes: model.axes
                    hats: model.hats
                    photo: model.photo
                    isStub: model.isStub
                    isModule: model.isModule
                    tab: model.tab
                    target: model.target
                    lastLine: model.lastLine
                    lastHardware: model.lastHardware
                    focused: model.focused
                    pinActive: _page.pinSlug === model.slug
                    hoverPeek: _page.hoverPeek
                    width: {
                        var avail = _flow.width
                        var cols = Math.max(1, Math.floor((avail + 12) / 332))
                        var w = Math.floor((avail - (cols - 1) * 12) / cols)
                        return Math.min(420, Math.max(260, w))
                    }

                    onCardFocused: _page.focusSlug(slug)
                    onOpenConfiguration: _page.openConfiguration(_page.pack(model))
                    onConfigureModule: _page.configureModule(_page.pack(model))
                    onPinControlDisplay: _page.pinControlDisplay(_page.pack(model))
                    onAutoMap: _page.autoMap(_page.pack(model))
                    onOpenDeviceViewer: _page.openDeviceViewer(_page.pack(model))
                    onOpenPairing: _page.openPairing(_page.pack(model))
                    onOpenCalibration: _page.openCalibration(_page.pack(model))
                    onOpenDeviceInformation: _page.openDeviceInformation(_page.pack(model))
                    onAssignHardware: _page.assignHardware(_page.pack(model))
                    onIgnoreDevice: _page.ignoreDevice(_page.pack(model))
                    onDropAt: function(cx, cy) { _page.placeSlug(slug, cx, cy) }
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: _repeater.count === 0
        text: "No devices to show. Plug in hardware or unhide a card from View → Hidden devices…"
        color: "#A1A1AA"
    }
}
