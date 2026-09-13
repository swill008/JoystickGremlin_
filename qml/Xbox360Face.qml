// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls

Item {
    id: _root

    property int padId: 1
    property var live: null
    property int stamp: 0

    implicitWidth: 420
    implicitHeight: 360

    function v(name) {
        if (!live)
            return 0
        return stamp >= 0 ? live.xboxValue(padId, name) : 0
    }
    function on(name) {
        return v(name) > 0.5
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Xbox 360  " + padId
            color: "#94a3b8"
            font.pixelSize: 11
        }

        Item {
            width: 360
            height: 118

            Text {
                x: 18; y: 2
                text: "LB"
                color: on("left_shoulder") ? "#86EFAC" : "#64748b"
                font.pixelSize: 10
            }
            Text {
                x: width - 34; y: 2
                text: "RB"
                color: on("right_shoulder") ? "#86EFAC" : "#64748b"
                font.pixelSize: 10
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 18
                width: 300
                height: 58
                radius: 22
                color: "#f4f4f5"
                border.color: "#d4d4d8"
                border.width: 1

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    width: 18
                    height: 10
                    radius: 2
                    color: "#3f3f46"
                }

                Rectangle {
                    x: 18; y: 16
                    width: 64; height: 26; radius: 8
                    color: on("left_shoulder") ? "#22C55E" : "#e4e4e7"
                    border.color: on("left_shoulder") ? "#86EFAC" : "#a1a1aa"
                    Text {
                        anchors.centerIn: parent
                        text: "LB"
                        color: on("left_shoulder") ? "#052e16" : "#3f3f46"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
                Rectangle {
                    x: parent.width - 82; y: 16
                    width: 64; height: 26; radius: 8
                    color: on("right_shoulder") ? "#22C55E" : "#e4e4e7"
                    border.color: on("right_shoulder") ? "#86EFAC" : "#a1a1aa"
                    Text {
                        anchors.centerIn: parent
                        text: "RB"
                        color: on("right_shoulder") ? "#052e16" : "#3f3f46"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Rectangle {
                x: 62
                y: 72
                width: 22
                height: 28 + 18 * Math.min(1.0, Math.max(0.0, v("left_trigger")))
                radius: 6
                color: v("left_trigger") > 0.08 ? "#38BDF8" : "#71717a"
            }
            Rectangle {
                x: parent.width - 84
                y: 72
                width: 22
                height: 28 + 18 * Math.min(1.0, Math.max(0.0, v("right_trigger")))
                radius: 6
                color: v("right_trigger") > 0.08 ? "#38BDF8" : "#71717a"
            }

            Text {
                x: 36; y: 98
                text: "LT"
                color: v("left_trigger") > 0.08 ? "#7dd3fc" : "#64748b"
                font.pixelSize: 10
            }
            Text {
                x: parent.width - 58; y: 98
                text: "RT"
                color: v("right_trigger") > 0.08 ? "#7dd3fc" : "#64748b"
                font.pixelSize: 10
            }
        }

        Item {
            width: 360
            height: 210

            Rectangle {
                anchors.fill: parent
                radius: 80
                color: "#f4f4f5"
                border.color: "#d4d4d8"
                border.width: 1
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 168
                height: 36
                radius: 18
                color: "#e4e4e7"
            }

            Item {
                x: 42
                y: 36
                width: 64
                height: 64
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#3f3f46"
                    border.color: on("left_thumb") ? "#22C55E" : "#27272a"
                    border.width: 3
                }
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "#d4d4d8"
                    x: 21 + 16 * Math.max(-1, Math.min(1, v("left_stick_x")))
                    y: 21 - 16 * Math.max(-1, Math.min(1, v("left_stick_y")))
                }
            }

            Item {
                x: 78
                y: 118
                width: 56
                height: 56
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 56
                    radius: 4
                    color: "#3f3f46"
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 56
                    height: 18
                    radius: 4
                    color: "#3f3f46"
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: 16; height: 16; radius: 3
                    color: on("dpad_up") ? "#f8fafc" : "#52525b"
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 40
                    width: 16; height: 16; radius: 3
                    color: on("dpad_down") ? "#f8fafc" : "#52525b"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 0
                    width: 16; height: 16; radius: 3
                    color: on("dpad_left") ? "#f8fafc" : "#52525b"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 40
                    width: 16; height: 16; radius: 3
                    color: on("dpad_right") ? "#f8fafc" : "#52525b"
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 58
                spacing: 10
                Rectangle {
                    width: 40; height: 16; radius: 8
                    color: on("back") ? "#22C55E" : "#e4e4e7"
                    border.color: "#a1a1aa"
                    Text {
                        anchors.centerIn: parent
                        text: "BACK"
                        color: on("back") ? "#052e16" : "#3f3f46"
                        font.pixelSize: 8
                    }
                }
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: on("guide") ? "#4ade80" : "#16a34a"
                    border.color: "#86efac"
                    border.width: on("guide") ? 3 : 2
                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
                Rectangle {
                    width: 40; height: 16; radius: 8
                    color: on("start") ? "#22C55E" : "#e4e4e7"
                    border.color: "#a1a1aa"
                    Text {
                        anchors.centerIn: parent
                        text: "START"
                        color: on("start") ? "#052e16" : "#3f3f46"
                        font.pixelSize: 8
                    }
                }
            }

            Item {
                x: 248
                y: 36
                width: 78
                height: 78
                Rectangle {
                    x: 29; y: 0; width: 22; height: 22; radius: 11
                    color: on("y") ? "#fde047" : "#ca8a04"
                    Text { anchors.centerIn: parent; text: "Y"; color: "white"; font.pixelSize: 11; font.bold: true }
                }
                Rectangle {
                    x: 56; y: 29; width: 22; height: 22; radius: 11
                    color: on("b") ? "#f87171" : "#dc2626"
                    Text { anchors.centerIn: parent; text: "B"; color: "white"; font.pixelSize: 11; font.bold: true }
                }
                Rectangle {
                    x: 29; y: 56; width: 22; height: 22; radius: 11
                    color: on("a") ? "#4ade80" : "#16a34a"
                    Text { anchors.centerIn: parent; text: "A"; color: "white"; font.pixelSize: 11; font.bold: true }
                }
                Rectangle {
                    x: 0; y: 29; width: 22; height: 22; radius: 11
                    color: on("x") ? "#60a5fa" : "#2563eb"
                    Text { anchors.centerIn: parent; text: "X"; color: "white"; font.pixelSize: 11; font.bold: true }
                }
            }

            Item {
                x: 232
                y: 122
                width: 64
                height: 64
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#3f3f46"
                    border.color: on("right_thumb") ? "#22C55E" : "#27272a"
                    border.width: 3
                }
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: "#d4d4d8"
                    x: 21 + 16 * Math.max(-1, Math.min(1, v("right_stick_x")))
                    y: 21 - 16 * Math.max(-1, Math.min(1, v("right_stick_y")))
                }
            }
        }
    }
}
