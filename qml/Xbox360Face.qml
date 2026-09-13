// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick

Item {
    id: _root

    property int padId: 1
    property var live: null
    property int stamp: 0

    implicitWidth: 380
    implicitHeight: 580

    readonly property real _ox: _img.x + (_img.width - _img.paintedWidth) * 0.5
    readonly property real _oy: _img.y + (_img.height - _img.paintedHeight) * 0.5
    readonly property real _pw: _img.paintedWidth
    readonly property real _ph: _img.paintedHeight

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
    function ps(n) { return n * Math.min(_pw, _ph) }

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
        y: 2
        text: _img.status === Image.Error ? "Xbox face image missing" : ("Xbox 360  " + padId)
        color: "#94a3b8"
        font.pixelSize: 11
        z: 4
    }

    Text { x: px(0.10); y: py(0.10); text: "LB"; color: on("left_shoulder") ? "#86EFAC" : "#94a3b8"; font.pixelSize: 10; font.bold: true }
    Text { x: px(0.86); y: py(0.10); text: "RB"; color: on("right_shoulder") ? "#86EFAC" : "#94a3b8"; font.pixelSize: 10; font.bold: true }
    Text { x: px(0.22); y: py(0.40); text: "LT"; color: v("left_trigger") > 0.08 ? "#7dd3fc" : "#94a3b8"; font.pixelSize: 10; font.bold: true }
    Text { x: px(0.74); y: py(0.40); text: "RT"; color: v("right_trigger") > 0.08 ? "#7dd3fc" : "#94a3b8"; font.pixelSize: 10; font.bold: true }

    Rectangle {
        x: px(0.16); y: py(0.16); width: ps(0.16); height: ps(0.06); radius: 6
        color: "#00000000"
        border.width: on("left_shoulder") ? 3 : 0
        border.color: "#22C55E"
    }
    Rectangle {
        x: px(0.68); y: py(0.16); width: ps(0.16); height: ps(0.06); radius: 6
        color: "#00000000"
        border.width: on("right_shoulder") ? 3 : 0
        border.color: "#22C55E"
    }

    Rectangle {
        x: px(0.30); y: py(0.26)
        width: ps(0.07)
        height: ps(0.08) + ps(0.06) * Math.min(1.0, Math.max(0.0, v("left_trigger")))
        radius: 6
        color: v("left_trigger") > 0.08 ? "#6638BDF8" : "#00000000"
        border.width: v("left_trigger") > 0.08 ? 2 : 0
        border.color: "#38BDF8"
    }
    Rectangle {
        x: px(0.63); y: py(0.26)
        width: ps(0.07)
        height: ps(0.08) + ps(0.06) * Math.min(1.0, Math.max(0.0, v("right_trigger")))
        radius: 6
        color: v("right_trigger") > 0.08 ? "#6638BDF8" : "#00000000"
        border.width: v("right_trigger") > 0.08 ? 2 : 0
        border.color: "#38BDF8"
    }

    Item {
        x: px(0.236); y: py(0.598)
        width: ps(0.12); height: ps(0.12)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#00000000"
            border.width: on("left_thumb") ? 3 : 0
            border.color: "#22C55E"
        }
        Rectangle {
            width: parent.width * 0.28
            height: width
            radius: width / 2
            color: "#e5e7eb"
            visible: Math.abs(v("left_stick_x")) > 0.06 || Math.abs(v("left_stick_y")) > 0.06 || on("left_thumb")
            x: parent.width * 0.36 + parent.width * 0.28 * Math.max(-1, Math.min(1, v("left_stick_x")))
            y: parent.height * 0.36 - parent.height * 0.28 * Math.max(-1, Math.min(1, v("left_stick_y")))
        }
    }

    Rectangle { x: px(0.318); y: py(0.718); width: ps(0.035); height: ps(0.035); radius: 3; color: on("dpad_up") ? "#ccf8fafc" : "#00000000" }
    Rectangle { x: px(0.318); y: py(0.778); width: ps(0.035); height: ps(0.035); radius: 3; color: on("dpad_down") ? "#ccf8fafc" : "#00000000" }
    Rectangle { x: px(0.286); y: py(0.748); width: ps(0.035); height: ps(0.035); radius: 3; color: on("dpad_left") ? "#ccf8fafc" : "#00000000" }
    Rectangle { x: px(0.350); y: py(0.748); width: ps(0.035); height: ps(0.035); radius: 3; color: on("dpad_right") ? "#ccf8fafc" : "#00000000" }

    Rectangle {
        x: px(0.445); y: py(0.638)
        width: ps(0.11); height: ps(0.11); radius: width / 2
        color: "#00000000"
        border.width: on("guide") ? 4 : 0
        border.color: "#4ade80"
    }

    Rectangle {
        x: px(0.392); y: py(0.862); width: ps(0.07); height: ps(0.028); radius: 6
        color: on("back") ? "#9922C55E" : "#00000000"
        border.width: on("back") ? 2 : 0
        border.color: "#86EFAC"
    }
    Rectangle {
        x: px(0.538); y: py(0.862); width: ps(0.07); height: ps(0.028); radius: 6
        color: on("start") ? "#9922C55E" : "#00000000"
        border.width: on("start") ? 2 : 0
        border.color: "#86EFAC"
    }

    Rectangle { x: px(0.678); y: py(0.598); width: ps(0.055); height: ps(0.055); radius: width / 2; color: on("y") ? "#99fde047" : "#00000000"; border.width: on("y") ? 3 : 0; border.color: "#facc15" }
    Rectangle { x: px(0.728); y: py(0.638); width: ps(0.055); height: ps(0.055); radius: width / 2; color: on("b") ? "#99f87171" : "#00000000"; border.width: on("b") ? 3 : 0; border.color: "#f87171" }
    Rectangle { x: px(0.678); y: py(0.678); width: ps(0.055); height: ps(0.055); radius: width / 2; color: on("a") ? "#994ade80" : "#00000000"; border.width: on("a") ? 3 : 0; border.color: "#4ade80" }
    Rectangle { x: px(0.628); y: py(0.638); width: ps(0.055); height: ps(0.055); radius: width / 2; color: on("x") ? "#9960a5fa" : "#00000000"; border.width: on("x") ? 3 : 0; border.color: "#60a5fa" }

    Item {
        x: px(0.568); y: py(0.718)
        width: ps(0.12); height: ps(0.12)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#00000000"
            border.width: on("right_thumb") ? 3 : 0
            border.color: "#22C55E"
        }
        Rectangle {
            width: parent.width * 0.28
            height: width
            radius: width / 2
            color: "#e5e7eb"
            visible: Math.abs(v("right_stick_x")) > 0.06 || Math.abs(v("right_stick_y")) > 0.06 || on("right_thumb")
            x: parent.width * 0.36 + parent.width * 0.28 * Math.max(-1, Math.min(1, v("right_stick_x")))
            y: parent.height * 0.36 - parent.height * 0.28 * Math.max(-1, Math.min(1, v("right_stick_y")))
        }
    }
}
