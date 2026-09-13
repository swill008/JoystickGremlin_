// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Device
import Gremlin.Style

ColumnLayout {
    id: _root

    property string deviceGuid: ""
    property string title: ""
    property string pairLabel: ""
    property int axisStamp: _live && _live.axisStamp !== undefined ? _live.axisStamp : (_live ? _live.stamp : 0)
    property int buttonStamp: _live && _live.buttonStamp !== undefined ? _live.buttonStamp : (_live ? _live.stamp : 0)
    property int xboxStamp: _live && _live.xboxStamp !== undefined ? _live.xboxStamp : 0
    property bool pairActive: backend && backend.gremlinActive

    spacing: 4

    MappedAxisModel { id: _axes; guid: deviceGuid }
    MappedButtonModel { id: _buttons; guid: deviceGuid }
    MappedHatModel { id: _hats; guid: deviceGuid }
    MappedXboxPadModel { id: _xboxPads; guid: deviceGuid }
    PairLiveThrottle { id: _live; guid: deviceGuid }

    function hwAxis(id) {
        if (!_live) return 0
        return axisStamp >= 0 ? _live.axisValue(id) : 0
    }
    function vjAxis(g, id) {
        if (!_live) return 0
        return axisStamp >= 0 ? _live.vjoyAxisValue(g, id) : 0
    }
    function hwButton(id) {
        if (!_live) return 0
        return buttonStamp >= 0 ? _live.buttonValue(id) : 0
    }
    function vjButton(g, id) {
        if (!_live) return 0
        return buttonStamp >= 0 ? _live.vjoyButtonValue(g, id) : 0
    }
    function xb(pad, target) {
        if (!_live) return 0
        return xboxStamp >= 0 ? _live.xboxValue(pad, target) : 0
    }
    function destLabel(kind, vlabel, xlabel) {
        return kind === "xbox" ? xlabel : vlabel
    }
    function destAxis(kind, guid, input, pad, target) {
        if (kind === "xbox") {
            var value = xb(pad, target)
            if (String(target).indexOf("trigger") >= 0)
                return value * 2.0 - 1.0
            return value
        }
        return vjAxis(guid, input)
    }
    function destOn(kind, guid, input, pad, target) {
        if (kind === "xbox")
            return xb(pad, target) > 0.5
        return vjButton(guid, input) > 0.5
    }
    function destChip(kind, input, target) {
        if (kind === "xbox") {
            var parts = String(target || "").split("_")
            return parts.length ? parts[parts.length - 1].slice(0, 3) : "xb"
        }
        return String(input)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: _inner.implicitHeight + 16
        color: pairActive ? "#052e16" : Style.background
        border.color: pairActive ? "#22C55E" : Style.accent
        border.width: pairActive ? 2 : 1
        radius: 6
        clip: true

        ColumnLayout {
            id: _inner
            width: parent.width - 16
            x: 8
            y: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                JGText { text: title; font.pointSize: 12 }
                Rectangle {
                    visible: pairActive
                    width: 8; height: 8; radius: 4; color: "#22C55E"
                }
                JGText {
                    visible: pairActive
                    text: "Active"
                    color: "#22C55E"
                    font.pointSize: 10
                }
                Item { Layout.fillWidth: true }
                JGText {
                    visible: pairLabel.length > 0
                    text: "\u2192  " + pairLabel
                    color: pairActive ? "#86EFAC" : Style.accent
                }
                Switch { id: _temporal; text: "Axes - Temporal" }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: _temporal.checked ? 200 : 0
                visible: _temporal.checked
                clip: true
                Loader {
                    anchors.fill: parent
                    active: _temporal.checked
                    source: Qt.resolvedUrl("AxesStateSeries.qml")
                    onLoaded: {
                        if (item) {
                            item.deviceGuid = _root.deviceGuid
                            item.title = ""
                        }
                    }
                }
            }

            JGText { text: "Mapped axes"; opacity: 0.7; font.pointSize: 10 }

            Repeater {
                model: _axes
                delegate: RowLayout {
                    required property int identifier
                    required property string label
                    required property string vjoyLabel
                    required property string vjoyGuid
                    required property int vjoyInput
                    required property string destKind
                    required property int xboxPad
                    required property string xboxTarget
                    required property string xboxLabel
                    Layout.fillWidth: true
                    spacing: 8
                    Label { text: label; color: Style.foreground; Layout.preferredWidth: 28; font.pointSize: 10 }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Style.lowColor
                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: parent.width * Math.min(1.0, Math.max(0.0, (hwAxis(identifier) + 1.0) * 0.5))
                            color: "#22C55E"
                        }
                    }
                    Label {
                        text: destLabel(destKind, vjoyLabel, xboxLabel)
                        color: destKind === "xbox" ? "#86EFAC" : Style.accent
                        Layout.preferredWidth: 110
                        font.pointSize: 9
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Style.lowColor
                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: parent.width * Math.min(1.0, Math.max(0.0, (destAxis(destKind, vjoyGuid, vjoyInput, xboxPad, xboxTarget) + 1.0) * 0.5))
                            color: destKind === "xbox" ? "#22C55E" : "#38BDF8"
                        }
                    }
                }
            }

            JGText { text: "Mapped buttons"; opacity: 0.7; font.pointSize: 10 }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: _btnFlow.implicitHeight + 16
                color: "transparent"
                border.color: Style.medColor
                border.width: 1
                radius: 6
                Flow {
                    id: _btnFlow
                    width: parent.width - 16
                    x: 8; y: 8; spacing: 10
                    Repeater {
                        model: _buttons
                        delegate: Rectangle {
                            required property int identifier
                            required property string label
                            required property string vjoyLabel
                            required property string vjoyGuid
                            required property int vjoyInput
                            required property string destKind
                            required property int xboxPad
                            required property string xboxTarget
                            required property string xboxLabel
                            property bool hwOn: hwButton(identifier) > 0.5
                            property bool vjOn: destOn(destKind, vjoyGuid, vjoyInput, xboxPad, xboxTarget)
                            width: 40; height: 18; radius: 3
                            color: Style.background
                            border.color: (hwOn || vjOn) ? "#22C55E" : Style.medColor
                            border.width: 1
                            clip: true
                            Row {
                                anchors.fill: parent
                                Rectangle {
                                    width: parent.width / 2; height: parent.height
                                    color: hwOn ? "#22C55E" : "transparent"
                                    Label {
                                        anchors.centerIn: parent
                                        text: label
                                        color: hwOn ? "#052e16" : Style.foreground
                                        font.pointSize: 8
                                    }
                                    HoverHandler { id: _hwHover }
                                    ToolTip.visible: _hwHover.hovered
                                    ToolTip.delay: 200
                                    ToolTip.text: "Hardware " + label
                                }
                                Rectangle { width: 1; height: parent.height; color: Style.medColor }
                                Rectangle {
                                    width: parent.width / 2 - 1; height: parent.height
                                    color: vjOn ? "#38BDF8" : "transparent"
                                    Label {
                                        anchors.centerIn: parent
                                        text: destChip(destKind, vjoyInput, xboxTarget)
                                        color: vjOn ? "#0b1220" : Style.foreground
                                        font.pointSize: 8
                                    }
                                    HoverHandler { id: _vjHover }
                                    ToolTip.visible: _vjHover.hovered
                                    ToolTip.delay: 200
                                    ToolTip.text: destLabel(destKind, vjoyLabel, xboxLabel)
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: _hats
                delegate: RowLayout {
                    required property int identifier
                    required property string label
                    required property string destKind
                    required property string vjoyLabel
                    required property string xboxLabel
                    Layout.fillWidth: true
                    JGText {
                        text: label + "  \u2192  " + destLabel(destKind, vjoyLabel, xboxLabel)
                        font.pointSize: 10
                    }
                }
            }

            Flow {
                visible: _xboxPads.count > 0
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: _xboxPads
                    delegate: Xbox360Face {
                        required property int padId
                        live: _live
                        stamp: xboxStamp
                    }
                }
            }
        }
    }
}
