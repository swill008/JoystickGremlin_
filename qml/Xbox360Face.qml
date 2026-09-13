// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick

Item {
    id: _root

    property int padId: 1
    property var live: null
    property int stamp: 0

    implicitWidth: 520
    implicitHeight: 410

    readonly property real _ox: _img.x + (_img.width - _img.paintedWidth) * 0.5
    readonly property real _oy: _img.y + (_img.height - _img.paintedHeight) * 0.5
    readonly property real _pw: Math.max(1, _img.paintedWidth)
    readonly property real _ph: Math.max(1, _img.paintedHeight)

    function v(name) {
        if (!live || typeof live.xboxValue !== "function")
            return 0
        return stamp >= 0 ? live.xboxValue(padId, name) : 0
    }
    function on(name) {
        return stamp >= 0 && v(name) > 0.5
    }
    function px(nx) { return _ox + nx * _pw }
    function py(ny) { return _oy + ny * _ph }
    function pw(n) { return n * _pw }
    function ph(n) { return n * _ph }

    Image {
        id: _img
        anchors.fill: parent
        source: Qt.resolvedUrl("images/xbox360_two_panel.jpg")
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        text: _img.status === Image.Error ? "Xbox face image missing" : ("Xbox 360  " + padId)
        color: "#94a3b8"
        font.pixelSize: 11
        z: 4
    }

    // Always-visible outline; fills only when live.
    component Hotspot: Rectangle {
        property real nx
        property real ny
        property real nw
        property real nh
        property bool lit: false
        property color glow: "#22C55E"
        property color fill: "#6622C55E"

        x: px(nx) - pw(nw) * 0.5
        y: py(ny) - ph(nh) * 0.5
        width: pw(nw)
        height: ph(nh)
        color: lit ? fill : "#00000000"
        border.width: lit ? 3 : 2
        border.color: lit ? glow : Qt.rgba(glow.r, glow.g, glow.b, 0.55)
        radius: Math.min(width, height) * 0.35
    }

    Hotspot { nx: 0.258; ny: 0.168; nw: 0.16; nh: 0.09; lit: on("left_shoulder"); glow: "#86EFAC"; fill: "#6622C55E"; radius: 8 }
    Hotspot { nx: 0.74; ny: 0.175; nw: 0.16; nh: 0.09; lit: on("right_shoulder"); glow: "#86EFAC"; fill: "#6622C55E"; radius: 8 }

    Hotspot {
        nx: 0.248; ny: 0.30; nw: 0.07
        nh: 0.13 + 0.04 * Math.min(1.0, Math.max(0.0, v("left_trigger")))
        lit: v("left_trigger") > 0.08
        glow: "#38BDF8"; fill: "#8838BDF8"; radius: 6
    }
    Hotspot {
        nx: 0.788; ny: 0.30; nw: 0.07
        nh: 0.13 + 0.04 * Math.min(1.0, Math.max(0.0, v("right_trigger")))
        lit: v("right_trigger") > 0.08
        glow: "#38BDF8"; fill: "#8838BDF8"; radius: 6
    }

    Item {
        x: px(0.298) - pw(0.12) * 0.5
        y: py(0.542) - pw(0.12) * 0.5
        width: pw(0.12); height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: on("left_thumb") ? "#3322C55E" : "#00000000"
            border.width: on("left_thumb") ? 3 : 2
            border.color: on("left_thumb") ? "#22C55E" : "#99EAB308"
        }
        Rectangle {
            width: parent.width * 0.22
            height: width
            radius: width / 2
            color: "#f8fafc"
            opacity: 0.9
            x: (parent.width - width) * 0.5 + parent.width * 0.28 * Math.max(-1, Math.min(1, v("left_stick_x")))
            y: (parent.height - height) * 0.5 - parent.height * 0.28 * Math.max(-1, Math.min(1, v("left_stick_y")))
        }
    }

    Item {
        x: px(0.632) - pw(0.12) * 0.5
        y: py(0.705) - pw(0.12) * 0.5
        width: pw(0.12); height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: on("right_thumb") ? "#3322C55E" : "#00000000"
            border.width: on("right_thumb") ? 3 : 2
            border.color: on("right_thumb") ? "#22C55E" : "#99EAB308"
        }
        Rectangle {
            width: parent.width * 0.22
            height: width
            radius: width / 2
            color: "#f8fafc"
            opacity: 0.9
            x: (parent.width - width) * 0.5 + parent.width * 0.28 * Math.max(-1, Math.min(1, v("right_stick_x")))
            y: (parent.height - height) * 0.5 - parent.height * 0.28 * Math.max(-1, Math.min(1, v("right_stick_y")))
        }
    }

    Hotspot { nx: 0.400; ny: 0.685; nw: 0.038; nh: 0.042; lit: on("dpad_up"); glow: "#f8fafc"; fill: "#66f8fafc"; radius: 3 }
    Hotspot { nx: 0.400; ny: 0.775; nw: 0.038; nh: 0.042; lit: on("dpad_down"); glow: "#f8fafc"; fill: "#66f8fafc"; radius: 3 }
    Hotspot { nx: 0.365; ny: 0.730; nw: 0.038; nh: 0.042; lit: on("dpad_left"); glow: "#f8fafc"; fill: "#66f8fafc"; radius: 3 }
    Hotspot { nx: 0.435; ny: 0.730; nw: 0.038; nh: 0.042; lit: on("dpad_right"); glow: "#f8fafc"; fill: "#66f8fafc"; radius: 3 }

    Hotspot { nx: 0.505; ny: 0.575; nw: 0.095; nh: 0.095 * _pw / _ph; lit: on("guide"); glow: "#4ade80"; fill: "#00000000"; radius: width / 2 }

    Hotspot { nx: 0.738; ny: 0.512; nw: 0.05; nh: 0.055 * _pw / _ph; lit: on("y"); glow: "#facc15"; fill: "#66fde047"; radius: width / 2 }
    Hotspot { nx: 0.785; ny: 0.575; nw: 0.05; nh: 0.055 * _pw / _ph; lit: on("b"); glow: "#f87171"; fill: "#66f87171"; radius: width / 2 }
    Hotspot { nx: 0.738; ny: 0.638; nw: 0.05; nh: 0.055 * _pw / _ph; lit: on("a"); glow: "#4ade80"; fill: "#664ade80"; radius: width / 2 }
    Hotspot { nx: 0.688; ny: 0.575; nw: 0.05; nh: 0.055 * _pw / _ph; lit: on("x"); glow: "#60a5fa"; fill: "#6660a5fa"; radius: width / 2 }

    Hotspot { nx: 0.458; ny: 0.572; nw: 0.026; nh: 0.022; lit: on("back"); glow: "#86EFAC"; fill: "#6622C55E"; radius: 6 }
    Hotspot { nx: 0.548; ny: 0.572; nw: 0.026; nh: 0.022; lit: on("start"); glow: "#86EFAC"; fill: "#6622C55E"; radius: 6 }
}
