// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Gremlin.Style

Item {
    id: _root

    property int padId: 1
    property var live: null
    property int stamp: 0

    implicitWidth: 300
    implicitHeight: 168

    function v(name) {
        if (!live) {
            return 0
        }
        return stamp >= 0 ? live.xboxValue(padId, name) : 0
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#1a1f2b"
        border.color: "#3f4b63"
        border.width: 1

        Row {
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 88

            Column {
                spacing: 3
                Rectangle {
                    width: 52
                    height: 8
                    radius: 2
                    color: "#2a3142"
                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, v("left_trigger")))
                        height: parent.height
                        radius: 2
                        color: "#38BDF8"
                    }
                }
                Rectangle {
                    width: 52
                    height: 10
                    radius: 3
                    color: v("left_shoulder") > 0.5 ? "#22C55E" : "#3a4458"
                    Text {
                        anchors.centerIn: parent
                        text: "LB"
                        color: "white"
                        font.pixelSize: 8
                    }
                }
            }

            Column {
                spacing: 3
                Rectangle {
                    width: 52
                    height: 8
                    radius: 2
                    color: "#2a3142"
                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, v("right_trigger")))
                        height: parent.height
                        radius: 2
                        color: "#38BDF8"
                    }
                }
                Rectangle {
                    width: 52
                    height: 10
                    radius: 3
                    color: v("right_shoulder") > 0.5 ? "#22C55E" : "#3a4458"
                    Text {
                        anchors.centerIn: parent
                        text: "RB"
                        color: "white"
                        font.pixelSize: 8
                    }
                }
            }
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Xbox 360  " + padId
            color: "#94a3b8"
            font.pixelSize: 10
        }

        Item {
            x: 28
            y: 48
            width: 64
            height: 64
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#111827"
                border.color: v("left_thumb") > 0.5 ? "#22C55E" : "#4b5563"
                border.width: 2
            }
            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#e5e7eb"
                x: 23 + 18 * Math.max(-1, Math.min(1, v("left_stick_x")))
                y: 23 - 18 * Math.max(-1, Math.min(1, v("left_stick_y")))
            }
        }

        Item {
            x: 108
            y: 58
            width: 48
            height: 48
            Rectangle { x: 16; y: 0; width: 16; height: 16; radius: 2; color: v("dpad_up") > 0.5 ? "#f8fafc" : "#374151" }
            Rectangle { x: 16; y: 32; width: 16; height: 16; radius: 2; color: v("dpad_down") > 0.5 ? "#f8fafc" : "#374151" }
            Rectangle { x: 0; y: 16; width: 16; height: 16; radius: 2; color: v("dpad_left") > 0.5 ? "#f8fafc" : "#374151" }
            Rectangle { x: 32; y: 16; width: 16; height: 16; radius: 2; color: v("dpad_right") > 0.5 ? "#f8fafc" : "#374151" }
        }

        Row {
            x: 108
            y: 118
            spacing: 8
            Rectangle {
                width: 28; height: 12; radius: 6
                color: v("back") > 0.5 ? "#22C55E" : "#374151"
                Text { anchors.centerIn: parent; text: "Bak"; color: "white"; font.pixelSize: 7 }
            }
            Rectangle {
                width: 16; height: 16; radius: 8
                color: v("guide") > 0.5 ? "#22C55E" : "#107c10"
                Text { anchors.centerIn: parent; text: "X"; color: "white"; font.pixelSize: 8; font.bold: true }
            }
            Rectangle {
                width: 28; height: 12; radius: 6
                color: v("start") > 0.5 ? "#22C55E" : "#374151"
                Text { anchors.centerIn: parent; text: "Str"; color: "white"; font.pixelSize: 7 }
            }
        }

        Item {
            x: 168
            y: 88
            width: 52
            height: 52
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#111827"
                border.color: v("right_thumb") > 0.5 ? "#22C55E" : "#4b5563"
                border.width: 2
            }
            Rectangle {
                width: 16; height: 16; radius: 8; color: "#e5e7eb"
                x: 18 + 14 * Math.max(-1, Math.min(1, v("right_stick_x")))
                y: 18 - 14 * Math.max(-1, Math.min(1, v("right_stick_y")))
            }
        }

        Item {
            x: 228
            y: 44
            width: 60
            height: 60
            Rectangle {
                x: 22; y: 0; width: 16; height: 16; radius: 8
                color: v("y") > 0.5 ? "#facc15" : "#854d0e"
                Text { anchors.centerIn: parent; text: "Y"; color: "white"; font.pixelSize: 9; font.bold: true }
            }
            Rectangle {
                x: 44; y: 22; width: 16; height: 16; radius: 8
                color: v("b") > 0.5 ? "#f87171" : "#7f1d1d"
                Text { anchors.centerIn: parent; text: "B"; color: "white"; font.pixelSize: 9; font.bold: true }
            }
            Rectangle {
                x: 22; y: 44; width: 16; height: 16; radius: 8
                color: v("a") > 0.5 ? "#4ade80" : "#14532d"
                Text { anchors.centerIn: parent; text: "A"; color: "white"; font.pixelSize: 9; font.bold: true }
            }
            Rectangle {
                x: 0; y: 22; width: 16; height: 16; radius: 8
                color: v("x") > 0.5 ? "#60a5fa" : "#1e3a8a"
                Text { anchors.centerIn: parent; text: "X"; color: "white"; font.pixelSize: 9; font.bold: true }
            }
        }
    }
}
