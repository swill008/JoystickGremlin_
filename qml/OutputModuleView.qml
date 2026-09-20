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
    property bool showPanel: false
    readonly property bool runtimeActive: !!(backend && backend.gremlinActive)
    readonly property bool showLive: runtimeActive && !!( _live.driven)
    property int liveStamp: _live.stamp

    property string layout: "pads_meters_grid"
    property int padAX: 1
    property int padAY: 2
    property int padBX: 4
    property int padBY: 5
    property bool showHats: true
    property string meterStyle: "vertical"
    property int meterWidth: 22
    property var meters: []
    property string buttonStyle: "tile"
    property string buttonSize: "medium"
    property int buttonColumns: 12
    property string colorLive: "#22C55E"
    property string colorMeter: "#3B82F6"
    property string colorPress: "#22C55E"

    readonly property bool showPads: layout === "pads_meters_grid"
    readonly property bool showMeters: layout !== "grid_only"
    readonly property int btnCellW: buttonSize === "small" ? 52 : (buttonSize === "large" ? 88 : 64)
    readonly property int btnCellH: buttonSize === "small" ? 36 : (buttonSize === "large" ? 56 : 48)

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
        function onViewChanged() { _root.loadView() }
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

    function meterOn(hw) {
        if (!meters || meters.length === 0)
            return true
        return meters.indexOf(hw) >= 0 || meters.indexOf(Number(hw)) >= 0
    }

    function toggleMeter(hw, on) {
        var list = (meters || []).slice()
        var i = list.indexOf(hw)
        if (i < 0)
            i = list.indexOf(Number(hw))
        if (on && i < 0)
            list.push(hw)
        if (!on && i >= 0)
            list.splice(i, 1)
        meters = list
    }

    function viewPayload() {
        return {
            "layout": layout,
            "padAX": padAX,
            "padAY": padAY,
            "padBX": padBX,
            "padBY": padBY,
            "showHats": showHats,
            "meterStyle": meterStyle,
            "meterWidth": meterWidth,
            "meters": meters,
            "buttonStyle": buttonStyle,
            "buttonSize": buttonSize,
            "buttonColumns": buttonColumns,
            "colorLive": colorLive,
            "colorMeter": colorMeter,
            "colorPress": colorPress
        }
    }

    function loadView() {
        if (!moduleModel || !deviceName)
            return
        try {
            var v = JSON.parse(moduleModel.viewConfigJson(deviceName))
        } catch (e) {
            return
        }
        layout = v.layout || "pads_meters_grid"
        padAX = v.padAX || 1
        padAY = v.padAY || 2
        padBX = v.padBX || 4
        padBY = v.padBY || 5
        showHats = v.showHats !== false
        meterStyle = v.meterStyle || "vertical"
        meterWidth = v.meterWidth || 22
        meters = v.meters || []
        buttonStyle = v.buttonStyle || "tile"
        buttonSize = v.buttonSize || "medium"
        buttonColumns = v.buttonColumns || 12
        colorLive = v.colorLive || "#22C55E"
        colorMeter = v.colorMeter || "#3B82F6"
        colorPress = v.colorPress || "#22C55E"
    }

    function saveView() {
        if (moduleModel && deviceName)
            moduleModel.saveViewConfig(deviceName, JSON.stringify(viewPayload()))
    }

    function resetView() {
        layout = "pads_meters_grid"
        padAX = 1; padAY = 2; padBX = 4; padBY = 5
        showHats = true
        meterStyle = "vertical"
        meterWidth = 22
        meters = []
        buttonStyle = "tile"
        buttonSize = "medium"
        buttonColumns = 12
        colorLive = "#22C55E"
        colorMeter = "#3B82F6"
        colorPress = "#22C55E"
        saveView()
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
            if (k === "axis")
                axisModel.append({ "idx": j, "hw": hw, "name": axisShort(hw, "") })
            else if (k === "button")
                buttonModel.append({ "idx": j, "hw": hw, "name": "" + hw })
            else if (k === "hat")
                hatModel.append({ "idx": j, "hw": hw, "name": "Hat " + hw })
        }
    }

    Component.onCompleted: { loadView(); rebuild() }
    onGuidChanged: Qt.callLater(rebuild)
    onDeviceNameChanged: { loadView(); Qt.callLater(rebuild) }

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
            color: _root.colorLive
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
            visible: _root.showPads
            Layout.preferredWidth: 228
            Layout.maximumWidth: 228
            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            CrossPad {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 220
                label: "X / Y"
                xVal: { var row = findAxis(padAX); return row ? liveVal(row.idx) : 0 }
                yVal: { var row = findAxis(padAY); return row ? liveVal(row.idx) : 0 }
            }
            CrossPad {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 220
                visible: padBX > 0 || padBY > 0
                label: "Rx / Ry"
                xVal: { var row = findAxis(padBX); return row ? liveVal(row.idx) : 0 }
                yVal: { var row = findAxis(padBY); return row ? liveVal(row.idx) : 0 }
            }
            Repeater {
                model: hatModel
                delegate: HatView {
                    required property int idx
                    required property int hw
                    required property string name
                    visible: _root.showHats
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 160
                    Layout.alignment: Qt.AlignHCenter
                    text: name.length ? name : ("Hat " + hw)
                    currentValue: liveVal(idx) > 0.5 ? Qt.point(0, 1) : Qt.point(0, 0)
                }
            }
            Item { Layout.fillHeight: true }
        }

        Row {
            visible: _root.showMeters
            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 10

            Repeater {
                model: axisModel
                delegate: Column {
                    required property int idx
                    required property int hw
                    required property string name
                    visible: meterOn(hw)
                    width: Math.max(48, _root.meterWidth + 26)
                    height: parent.height
                    spacing: 6

                    BetterProgressBar {
                        width: _root.meterWidth
                        height: parent.height - 44
                        anchors.horizontalCenter: parent.horizontalCenter
                        orientation: _root.meterStyle === "horizontal" ? BetterProgressBar.Orientation.Horizontal : BetterProgressBar.Orientation.Vertical
                        barSize: _root.meterWidth
                        fillColor: _root.colorMeter
                        from: -1
                        to: 1
                        value: liveVal(idx)
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: axisShort(hw, name)
                        color: "#E4E4E7"
                        font.pixelSize: 12
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: (liveVal(idx) >= 0 ? "+" : "") + liveVal(idx).toFixed(2)
                        color: "#A1A1AA"
                        font.pixelSize: 10
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 200
            clip: true

            GridView {
                id: _buttons
                anchors.fill: parent
                clip: true
                cellWidth: {
                    var cols = Math.max(4, _root.buttonColumns)
                    return Math.max(40, Math.floor(width / cols))
                }
                cellHeight: _root.btnCellH
                model: buttonModel
                boundsBehavior: Flickable.StopAtBounds
                flow: GridView.FlowLeftToRight

                delegate: Rectangle {
                    required property int idx
                    required property int hw
                    required property string name
                    width: _buttons.cellWidth - 6
                    height: _buttons.cellHeight - 6
                    property bool on: liveVal(idx) > 0.5 && _root.showLive
                    color: {
                        if (!on)
                            return Style.background
                        if (_root.buttonStyle === "compact")
                            return _root.colorPress
                        return Qt.rgba(0.133, 0.773, 0.369, 0.45)
                    }
                    border.color: on ? _root.colorPress : Style.lowColor
                    border.width: 1
                    radius: 3

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            visible: _root.buttonStyle === "led"
                            width: 10
                            height: 10
                            radius: 5
                            color: on ? _root.colorPress : Style.lowColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: name && name.length ? name : ("" + hw)
                            color: on ? "#F4F4F5" : "#A1A1AA"
                            font.pixelSize: _root.buttonSize === "small" ? 11 : 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: _root.showPanel
            Layout.preferredWidth: 320
            Layout.maximumWidth: 320
            Layout.fillHeight: true
            color: "#18181B"
            border.color: "#3F3F46"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Label {
                        text: "Output Module View — Display"
                        color: "#E4E4E7"
                        font.bold: true
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                    Button {
                        text: "×"
                        implicitWidth: 28
                        onClicked: _root.showPanel = false
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ColumnLayout {
                        width: 290
                        spacing: 8

                        Label { text: "LAYOUT"; color: "#A1A1AA"; font.pixelSize: 10 }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["Pads + meters + grid", "Meters + grid", "Grid only"]
                            currentIndex: layout === "grid_only" ? 2 : (layout === "meters_grid" ? 1 : 0)
                            onActivated: {
                                layout = ["pads_meters_grid", "meters_grid", "grid_only"][currentIndex]
                            }
                        }

                        Label { text: "PADS"; color: "#A1A1AA"; font.pixelSize: 10 }
                        Label { text: "X / Y"; color: "#E4E4E7"; font.pixelSize: 11 }
                        RowLayout {
                            SpinBox { from: 0; to: 8; value: padAX; onValueModified: padAX = value; Layout.fillWidth: true }
                            SpinBox { from: 0; to: 8; value: padAY; onValueModified: padAY = value; Layout.fillWidth: true }
                        }
                        Label { text: "Rx / Ry  (0 = hide)"; color: "#E4E4E7"; font.pixelSize: 11 }
                        RowLayout {
                            SpinBox { from: 0; to: 8; value: padBX; onValueModified: padBX = value; Layout.fillWidth: true }
                            SpinBox { from: 0; to: 8; value: padBY; onValueModified: padBY = value; Layout.fillWidth: true }
                        }
                        CheckBox { text: "Show hats"; checked: showHats; onToggled: showHats = checked }

                        Label { text: "METERS"; color: "#A1A1AA"; font.pixelSize: 10 }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["Vertical bar", "Horizontal bar"]
                            currentIndex: meterStyle === "horizontal" ? 1 : 0
                            onActivated: meterStyle = currentIndex === 1 ? "horizontal" : "vertical"
                        }
                        RowLayout {
                            Label { text: "Width"; color: "#E4E4E7" }
                            SpinBox { from: 12; to: 48; value: meterWidth; onValueModified: meterWidth = value }
                        }
                        Repeater {
                            model: axisModel
                            delegate: CheckBox {
                                required property int hw
                                required property string name
                                text: axisShort(hw, name)
                                checked: meterOn(hw)
                                onToggled: toggleMeter(hw, checked)
                            }
                        }

                        Label { text: "BUTTONS"; color: "#A1A1AA"; font.pixelSize: 10 }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["Tile", "LED + number", "Compact"]
                            currentIndex: buttonStyle === "led" ? 1 : (buttonStyle === "compact" ? 2 : 0)
                            onActivated: buttonStyle = ["tile", "led", "compact"][currentIndex]
                        }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["Small", "Medium", "Large"]
                            currentIndex: buttonSize === "small" ? 0 : (buttonSize === "large" ? 2 : 1)
                            onActivated: buttonSize = ["small", "medium", "large"][currentIndex]
                        }
                        RowLayout {
                            Label { text: "Columns"; color: "#E4E4E7" }
                            SpinBox { from: 4; to: 16; value: buttonColumns; onValueModified: buttonColumns = value }
                        }

                        Label { text: "COLORS"; color: "#A1A1AA"; font.pixelSize: 10 }
                        RowLayout {
                            Label { text: "Live"; color: "#E4E4E7"; Layout.preferredWidth: 70 }
                            TextField { Layout.fillWidth: true; text: colorLive; onEditingFinished: colorLive = text }
                            Rectangle { width: 18; height: 18; color: colorLive; border.color: "#3F3F46" }
                        }
                        RowLayout {
                            Label { text: "Meter"; color: "#E4E4E7"; Layout.preferredWidth: 70 }
                            TextField { Layout.fillWidth: true; text: colorMeter; onEditingFinished: colorMeter = text }
                            Rectangle { width: 18; height: 18; color: colorMeter; border.color: "#3F3F46" }
                        }
                        RowLayout {
                            Label { text: "Press"; color: "#E4E4E7"; Layout.preferredWidth: 70 }
                            TextField { Layout.fillWidth: true; text: colorPress; onEditingFinished: colorPress = text }
                            Rectangle { width: 18; height: 18; color: colorPress; border.color: "#3F3F46" }
                        }
                    }
                }

                RowLayout {
                    Button { text: "Reset"; onClicked: resetView() }
                    Item { Layout.fillWidth: true }
                    Button { text: "Save with module"; highlighted: true; onClicked: saveView() }
                }
            }
        }
    }
}
