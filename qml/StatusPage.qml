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
                    onOpenConfiguration: _page.openConfiguration(model)
                    onConfigureModule: _page.configureModule(model)
                    onPinControlDisplay: _page.pinControlDisplay(model)
                    onAutoMap: _page.autoMap(model)
                    onOpenDeviceViewer: _page.openDeviceViewer(model)
                    onOpenPairing: _page.openPairing(model)
                    onOpenCalibration: _page.openCalibration(model)
                    onOpenDeviceInformation: _page.openDeviceInformation(model)
                    onAssignHardware: _page.assignHardware(model)
                    onIgnoreDevice: _page.ignoreDevice(model)
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
