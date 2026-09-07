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
    spacing: 0

    DeviceLiveState {
        id: _live
        guid: _fold.checked ? deviceGuid : ""
    }

    property int liveStamp: _live ? _live.stamp : 0
    property bool hasLive: liveStamp >= 0 && _live && _live.kindAt(0) !== ""

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: _inner.implicitHeight + 16
        color: "#101215"
        border.color: Style.medColor
        border.width: 1
        radius: 6

        ColumnLayout {
            id: _inner
            width: parent.width - 16
            x: 8
            y: 6
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                JGText {
                    text: title
                    opacity: 0.75
                    font.pointSize: 12
                }

                JGText {
                    text: "No Map to vJoy"
                    opacity: 0.45
                    font.pointSize: 10
                }

                Item { Layout.fillWidth: true }

                Switch {
                    id: _fold
                    text: "Live"
                }
            }

            ColumnLayout {
                visible: _fold.checked
                Layout.fillWidth: true
                Layout.preferredHeight: hasLive ? implicitHeight : 22
                spacing: 4

                JGText {
                    visible: !hasLive
                    text: "No live joystick data for this device"
                    opacity: 0.5
                    font.pointSize: 10
                }

                Repeater {
                    model: 16

                    delegate: RowLayout {
                        required property int index
                        visible: hasLive && _live.kindAt(index) === "axis"
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: "A" + (index + 1)
                            color: Style.foreground
                            opacity: 0.7
                            Layout.preferredWidth: 28
                            font.pointSize: 10
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Style.lowColor

                            Rectangle {
                                height: parent.height
                                radius: 2
                                width: parent.width * Math.min(1.0, Math.max(0.0, ((_live.valueAt(index) + 1.0) * 0.5)))
                                color: "#64748B"
                            }
                        }
                    }
                }

                Flow {
                    visible: hasLive
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: 64

                        delegate: Rectangle {
                            required property int index
                            visible: _live && _live.kindAt(index) === "button"
                            property bool on: liveStamp >= 0 && _live.valueAt(index) > 0.5
                            width: 28
                            height: 20
                            radius: 4
                            color: on ? "#334155" : "transparent"
                            border.color: on ? "#94A3B8" : Style.medColor
                            border.width: 1

                            Label {
                                anchors.centerIn: parent
                                text: String(index + 1)
                                color: Style.foreground
                                font.pointSize: 8
                                opacity: 0.8
                            }
                        }
                    }
                }
            }
        }
    }
}
