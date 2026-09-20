// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only
// View-only dest monitor: feeder live, no wiring.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts

import Gremlin.Device
import Gremlin.Style

Item {
    id: _root

    property var moduleModel: null
    property string guid: ""
    property string deviceName: ""
    readonly property bool runtimeActive: !!(backend && backend.gremlinActive)
    readonly property bool showLive: runtimeActive && !!( _live.driven)
    property int liveStamp: _live.stamp

    ModuleClaimedInputModel {
        id: _claimed
        guid: _root.guid
        deviceName: _root.deviceName
        onCountChanged: _root.rebuild()
    }

    DeviceLiveState {
        id: _live
        guid: _root.guid
        deviceName: _root.deviceName
        liveWhileActive: true
    }

    Connections {
        target: moduleModel
        function onClaimsChanged() { _claimed.reload(); _root.rebuild() }
    }

    ListModel { id: axisModel }
    ListModel { id: buttonModel }
    ListModel { id: hatModel }

    function axisShort(hw, name) {
        var map = { 1: "X", 2: "Y", 3: "Z", 4: "Rx", 5: "Ry", 6: "Rz", 7: "S1", 8: "S2" }
        if (map[hw])
            return map[hw]
        return name || ("A" + hw)
    }

    function liveVal(idx) {
        liveStamp
        if (!showLive || idx < 0)
            return 0
        return _live.valueAt(idx)
    }

    function findAxis(hw) {
        for (var i = 0; i < axisModel.count; ++i) {
            var row = axisModel.get(i)
            if (row.hw === hw)
                return row
        }
        return null
    }

    function rebuild() {
        axisModel.clear()
        buttonModel.clear()
        hatModel.clear()
        var n = _claimed.count
        if (n > 0) {
            for (var i = 0; i < n; ++i) {
                var kind = _claimed.kindAt(i)
                var rec = {
                    "idx": _claimed.deviceIndexAt(i),
                    "hw": _claimed.hwIdAt(i),
                    "name": _claimed.nameAt(i)
                }
                if (kind === "axis")
                    axisModel.append(rec)
                else if (kind === "button")
                    buttonModel.append(rec)
                else if (kind === "hat")
                    hatModel.append(rec)
            }
            return
        }
        for (var j = 0; j < 128; ++j) {
            var k = _live.kindAt(j)
            if (!k)
                break
            var hw = j + 1
            if (k === "axis") {
                hw = j + 1
                axisModel.append({ "idx": j, "hw": hw, "name": axisShort(hw, "") })
            } else if (k === "button") {
                buttonModel.append({ "idx": j, "hw": hw, "name": "" + hw })
            } else if (k === "hat") {
                hatModel.append({ "idx": j, "hw": hw, "name": "Hat " + hw })
            }
        }
    }

    Component.onCompleted: rebuild()
    onGuidChanged: Qt.callLater(rebuild)
    onDeviceNameChanged: Qt.callLater(rebuild)

    component CrossPad: Rectangle {
        id: pad
        property real xVal: 0
        property real yVal: 0
        property string label: ""
        color: Style.background
        border.color: Style.lowColor
        border.width: 1
        implicitWidth: 220
        implicitHeight: 220

        Rectangle {
            width: parent.width - 24
            height: 1
            color: Style.lowColor
            anchors.centerIn: parent
        }
        Rectangle {
            width: 1
            height: parent.height - 24
            color: Style.lowColor
            anchors.centerIn: parent
        }
        Rectangle {
            width: 12
            height: 12
            radius: 6
            color: "#22C55E"
            visible: _root.showLive
            x: parent.width / 2 + (pad.xVal * (parent.width / 2 - 16)) - width / 2
            y: parent.height / 2 - (pad.yVal * (parent.height / 2 - 16)) - height / 2
        }
        Label {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 6
            text: pad.label
            color: "#A1A1AA"
            font.pixelSize: 12
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 16

        ColumnLayout {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            spacing: 12

            CrossPad {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                label: "X / Y"
                xVal: {
                    var row = findAxis(1)
                    return row ? liveVal(row.idx) : 0
                }
                yVal: {
                    var row = findAxis(2)
                    return row ? liveVal(row.idx) : 0
                }
            }
            CrossPad {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                visible: findAxis(4) !== null || findAxis(5) !== null
                label: "Rx / Ry"
                xVal: {
                    var row = findAxis(4)
                    return row ? liveVal(row.idx) : 0
                }
                yVal: {
                    var row = findAxis(5)
                    return row ? liveVal(row.idx) : 0
                }
            }
            Repeater {
                model: hatModel
                delegate: HatView {
                    required property int idx
                    required property int hw
                    required property string name
                    required property int index
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 160
                    Layout.alignment: Qt.AlignHCenter
                    text: name.length ? name : ("Hat " + hw)
                    currentValue: liveVal(idx) > 0.5 ? Qt.point(0, 1) : Qt.point(0, 0)
                }
            }
            Item { Layout.fillHeight: true }
        }

        RowLayout {
            Layout.preferredWidth: Math.max(280, axisModel.count * 56)
            Layout.fillHeight: true
            spacing: 10

            Repeater {
                model: axisModel
                delegate: ColumnLayout {
                    required property int idx
                    required property int hw
                    required property string name
                    required property int index
                    Layout.fillHeight: true
                    Layout.preferredWidth: 48
                    spacing: 6

                    BetterProgressBar {
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        orientation: BetterProgressBar.Orientation.Vertical
                        barSize: 22
                        from: -1
                        to: 1
                        value: liveVal(idx)
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: axisShort(hw, name)
                        color: "#E4E4E7"
                        font.pixelSize: 12
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: (liveVal(idx) >= 0 ? "+" : "") + liveVal(idx).toFixed(2)
                        color: "#A1A1AA"
                        font.pixelSize: 10
                    }
                }
            }
        }

        GridView {
            id: _buttons
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 64
            cellHeight: 48
            model: buttonModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property int idx
                required property int hw
                required property string name
                required property int index
                width: _buttons.cellWidth - 6
                height: _buttons.cellHeight - 6
                color: (liveVal(idx) > 0.5 && _root.showLive) ? Qt.rgba(0.133, 0.773, 0.369, 0.45) : Style.background
                border.color: (liveVal(idx) > 0.5 && _root.showLive) ? "#22C55E" : Style.lowColor
                border.width: 1
                radius: 3

                Label {
                    anchors.centerIn: parent
                    text: name && name.length ? name : ("" + hw)
                    color: (liveVal(idx) > 0.5 && _root.showLive) ? "#F4F4F5" : "#A1A1AA"
                    font.pixelSize: 13
                }
            }
        }
    }
}
