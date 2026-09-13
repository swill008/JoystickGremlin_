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

    // Top LB bumper
    Rectangle {
        x: px(0.20); y: py(0.125); width: pw(0.18); height: ph(0.09); radius: 8
        color: on("left_shoulder") ? "#6622C55E" : "#00000000"
        border.width: on("left_shoulder") ? 2 : 0
        border.color: "#86EFAC"
    }
    // Top RB bumper
    Rectangle {
        x: px(0.62); y: py(0.125); width: pw(0.18); height: ph(0.09); radius: 8
        color: on("right_shoulder") ? "#6622C55E" : "#00000000"
        border.width: on("right_shoulder") ? 2 : 0
        border.color: "#86EFAC"
    }
    // Top LT paddle
    Rectangle {
        x: px(0.24); y: py(0.21); width: pw(0.07)
        height: ph(0.10) + ph(0.06) * Math.min(1.0, Math.max(0.0, v("left_trigger")))
        radius: 6
        color: v("left_trigger") > 0.08 ? "#8838BDF8" : "#00000000"
        border.width: v("left_trigger") > 0.08 ? 2 : 0
        border.color: "#38BDF8"
    }
    // Top RT paddle
    Rectangle {
        x: px(0.69); y: py(0.21); width: pw(0.07)
        height: ph(0.10) + ph(0.06) * Math.min(1.0, Math.max(0.0, v("right_trigger")))
        radius: 6
        color: v("right_trigger") > 0.08 ? "#8838BDF8" : "#00000000"
        border.width: v("right_trigger") > 0.08 ? 2 : 0
        border.color: "#38BDF8"
    }

    // Front left stick
    Item {
        x: px(0.168); y: py(0.50)
        width: pw(0.115); height: pw(0.115)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#00000000"
            border.width: on("left_thumb") ? 3 : 0
            border.color: "#22C55E"
        }
        Rectangle {
            width: parent.width * 0.30
            height: width
            radius: width / 2
            color: "#e5e7eb"
            visible: stamp >= 0 && (Math.abs(v("left_stick_x")) > 0.06 || Math.abs(v("left_stick_y")) > 0.06 || on("left_thumb"))
            x: parent.width * 0.35 + parent.width * 0.26 * Math.max(-1, Math.min(1, v("left_stick_x")))
            y: parent.height * 0.35 - parent.height * 0.26 * Math.max(-1, Math.min(1, v("left_stick_y")))
        }
    }

    // D-pad
    Rectangle { x: px(0.268); y: py(0.655); width: pw(0.035); height: ph(0.04); radius: 3; color: on("dpad_up") ? "#ccf8fafc" : "#00000000" }
    Rectangle { x: px(0.268); y: py(0.735); width: pw(0.035); height: ph(0.04); radius: 3; color: on("dpad_down") ? "#ccf8fafc" : "#00000000" }
    Rectangle { x: px(0.230); y: py(0.695); width: pw(0.035); height: ph(0.04); radius: 3; color: on("dpad_left") ? "#ccf8fafc" : "#00000000" }
    Rectangle { x: px(0.306); y: py(0.695); width: pw(0.035); height: ph(0.04); radius: 3; color: on("dpad_right") ? "#ccf8fafc" : "#00000000" }

    // Guide
    Rectangle {
        x: px(0.445); y: py(0.528)
        width: pw(0.11); height: pw(0.11); radius: width / 2
        color: "#00000000"
        border.width: on("guide") ? 4 : 0
        border.color: "#4ade80"
    }

    // ABXY on front
    Rectangle { x: px(0.678); y: py(0.488); width: pw(0.055); height: pw(0.055); radius: width / 2; color: on("y") ? "#99fde047" : "#00000000"; border.width: on("y") ? 3 : 0; border.color: "#facc15" }
    Rectangle { x: px(0.732); y: py(0.548); width: pw(0.055); height: pw(0.055); radius: width / 2; color: on("b") ? "#99f87171" : "#00000000"; border.width: on("b") ? 3 : 0; border.color: "#f87171" }
    Rectangle { x: px(0.678); y: py(0.608); width: pw(0.055); height: pw(0.055); radius: width / 2; color: on("a") ? "#994ade80" : "#00000000"; border.width: on("a") ? 3 : 0; border.color: "#4ade80" }
    Rectangle { x: px(0.624); y: py(0.548); width: pw(0.055); height: pw(0.055); radius: width / 2; color: on("x") ? "#9960a5fa" : "#00000000"; border.width: on("x") ? 3 : 0; border.color: "#60a5fa" }

    // Front right stick
    Item {
        x: px(0.528); y: py(0.655)
        width: pw(0.115); height: pw(0.115)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#00000000"
            border.width: on("right_thumb") ? 3 : 0
            border.color: "#22C55E"
        }
        Rectangle {
            width: parent.width * 0.30
            height: width
            radius: width / 2
            color: "#e5e7eb"
            visible: stamp >= 0 && (Math.abs(v("right_stick_x")) > 0.06 || Math.abs(v("right_stick_y")) > 0.06 || on("right_thumb"))
            x: parent.width * 0.35 + parent.width * 0.26 * Math.max(-1, Math.min(1, v("right_stick_x")))
            y: parent.height * 0.35 - parent.height * 0.26 * Math.max(-1, Math.min(1, v("right_stick_y")))
        }
    }

    // Back / Start next to Guide
    Rectangle {
        x: px(0.395); y: py(0.555); width: pw(0.045); height: ph(0.03); radius: 6
        color: on("back") ? "#9922C55E" : "#00000000"
        border.width: on("back") ? 2 : 0
        border.color: "#86EFAC"
    }
    Rectangle {
        x: px(0.560); y: py(0.555); width: pw(0.045); height: ph(0.03); radius: 6
        color: on("start") ? "#9922C55E" : "#00000000"
        border.width: on("start") ? 2 : 0
        border.color: "#86EFAC"
    }
}
