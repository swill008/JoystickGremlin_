// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls

Item {
    id: _root

    property int padId: 1
    property var live: null
    property int stamp: 0

    implicitWidth: 340
    implicitHeight: 210

    function v(name) {
        if (!live) {
            return 0
        }
        return stamp >= 0 ? live.xboxValue(padId, name) : 0
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#12151c"
        border.color: "#2a3140"
        border.width: 1

        Text {
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Xbox 360  " + padId
            color: "#94a3b8"
            font.pixelSize: 11
            z: 4
        }

        Item {
            id: _pad
            anchors.fill: parent
            anchors.margins: 8
            anchors.topMargin: 24

            Rectangle {
                x: 6
                y: 78
                width: 86
                height: 96
                radius: 40
                color: "#2a2f38"
                rotation: -18
            }
            Rectangle {
                x: _pad.width - 92
                y: 78
                width: 86
                height: 96
                radius: 40
                color: "#2a2f38"
                rotation: 18
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 18
                width: parent.width - 28
                height: 128
                radius: 56
                color: "#323843"
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 28
                width: 118
                height: 52
                radius: 26
                color: "#262b33"
            }

            Item {
                x: 28
                y: 4
                width: 70
                height: 22
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 10
                    radius: 4
                    color: "#1e232b"
                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, v("left_trigger")))
                        height: parent.height
                        radius: 4
                        color: "#e5e7eb"
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 12
                    radius: 5
                    color: v("left_shoulder") > 0.5 ? "#22C55E" : "#3d4450"
                    Text {
                        anchors.centerIn: parent
                        text: "LB"
                        color: "white"
                        font.pixelSize: 8
                    }
                }
            }

            Item {
                x: _pad.width - 98
                y: 4
                width: 70
                height: 22
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 10
                    radius: 4
                    color: "#1e232b"
                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, v("right_trigger")))
                        height: parent.height
                        radius: 4
                        color: "#e5e7eb"
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 12
                    radius: 5
                    color: v("right_shoulder") > 0.5 ? "#22C55E" : "#3d4450"
                    Text {
                        anchors.centerIn: parent
                        text: "RB"
                        color: "white"
                        font.pixelSize: 8
                    }
                }
            }

            Item {
                x: 42
                y: 52
                width: 56
                height: 56
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: 18
                    height: 48
                    radius: 4
                    color: "#1c2128"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 4
                    width: 48
                    height: 18
                    radius: 4
                    color: "#1c2128"
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: 16
                    height: 16
                    radius: 3
                    color: v("dpad_up") > 0.5 ? "#f8fafc" : "#3a414c"
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 36
                    width: 16
                    height: 16
                    radius: 3
                    color: v("dpad_down") > 0.5 ? "#f8fafc" : "#3a414c"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 4
                    width: 16
                    height: 16
                    radius: 3
                    color: v("dpad_left") > 0.5 ? "#f8fafc" : "#3a414c"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 36
                    width: 16
                    height: 16
                    radius: 3
                    color: v("dpad_right") > 0.5 ? "#f8fafc" : "#3a414c"
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 58
                spacing: 10
                Rectangle {
                    width: 36
                    height: 14
                    radius: 7
                    color: v("back") > 0.5 ? "#22C55E" : "#1c2128"
                    border.color: "#4b5563"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "BACK"
                        color: "white"
                        font.pixelSize: 7
                    }
                }
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: v("guide") > 0.5 ? "#4ade80" : "#16a34a"
                    border.color: "#86efac"
                    border.width: v("guide") > 0.5 ? 2 : 1
                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Rectangle {
                    width: 36
                    height: 14
                    radius: 7
                    color: v("start") > 0.5 ? "#22C55E" : "#1c2128"
                    border.color: "#4b5563"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "START"
                        color: "white"
                        font.pixelSize: 7
                    }
                }
            }

            Item {
                x: _pad.width - 108
                y: 46
                width: 72
                height: 72
                Rectangle {
                    x: 26; y: 0; width: 20; height: 20; radius: 10
                    color: v("y") > 0.5 ? "#facc15" : "#ca8a04"
                    Text { anchors.centerIn: parent; text: "Y"; color: "white"; font.pixelSize: 10; font.bold: true }
                }
                Rectangle {
                    x: 52; y: 26; width: 20; height: 20; radius: 10
                    color: v("b") > 0.5 ? "#f87171" : "#dc2626"
                    Text { anchors.centerIn: parent; text: "B"; color: "white"; font.pixelSize: 10; font.bold: true }
                }
                Rectangle {
                    x: 26; y: 52; width: 20; height: 20; radius: 10
                    color: v("a") > 0.5 ? "#4ade80" : "#16a34a"
                    Text { anchors.centerIn: parent; text: "A"; color: "white"; font.pixelSize: 10; font.bold: true }
                }
                Rectangle {
                    x: 0; y: 26; width: 20; height: 20; radius: 10
                    color: v("x") > 0.5 ? "#60a5fa" : "#2563eb"
                    Text { anchors.centerIn: parent; text: "X"; color: "white"; font.pixelSize: 10; font.bold: true }
                }
            }

            Item {
                x: 78
                y: 108
                width: 48
                height: 48
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#1c2128"
                    border.color: v("left_thumb") > 0.5 ? "#22C55E" : "#4b5563"
                    border.width: 2
                }
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "#c5c9d1"
                    x: 13 + 11 * Math.max(-1, Math.min(1, v("left_stick_x")))
                    y: 13 - 11 * Math.max(-1, Math.min(1, v("left_stick_y")))
                }
            }

            Item {
                x: _pad.width - 126
                y: 108
                width: 48
                height: 48
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#1c2128"
                    border.color: v("right_thumb") > 0.5 ? "#22C55E" : "#4b5563"
                    border.width: 2
                }
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "#c5c9d1"
                    x: 13 + 11 * Math.max(-1, Math.min(1, v("right_stick_x")))
                    y: 13 - 11 * Math.max(-1, Math.min(1, v("right_stick_y")))
                }
            }
        }
    }
}
