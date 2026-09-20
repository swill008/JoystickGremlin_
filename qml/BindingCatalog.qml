// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only
// Device-Configuration-Macro Change — grouped bindings catalog.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Dialogs

import Gremlin.Config
import Gremlin.Device
import Gremlin.Profile
import Gremlin.Style

Item {
    id: _root

    property Device device
    property var moduleModel: null
    property string claimDeviceName: ""
    property bool isOutput: false
    property int editingHid: -1
    property bool showPanel: false
    signal closePanel()
    readonly property bool editorLocked: backend && backend.gremlinActive && !isOutput
    readonly property bool runtimeActive: !!(backend && backend.gremlinActive)

    property int listPadding: 8
    property int rowSpacing: 4
    property int parentHeight: 50
    property int childHeight: 36
    property string parentAlign: "left"
    property int parentLeft: 0
    property int parentRight: 0
    property int parentWidthPct: 100
    property string childAlign: "left"
    property int childLeft: 24
    property int childRight: 24
    property int childWidthPct: 50
    property int parentFont: 13
    property int childFont: 12
    property int summaryFont: 12
    property bool parentBold: true
    property bool showChildren: true
    property bool showLiveBars: true
    property bool showLeds: true
    property bool showSummary: true
    property int rowRadius: 3
    property int nameColW: 180
    property int childNameColW: 160
    property int rowInnerPad: 10
    property int editorIndent: 12
    property string colorParent: "#111113"
    property string colorChild: "#111113"
    property string colorSelected: "#27272A"
    property string colorText: "#E4E4E7"
    property string colorMuted: "#A1A1AA"
    property string colorLive: "#22C55E"
    property string colorBorder: "#3F3F46"
    property string colorSelectBorder: "#E4E4E7"
    property string colorEditor: "#0F2744"
    property string colorEditorBorder: "#3B82F6"
    property string _colorTarget: "parent"
    property string toastText: "Display Options Saved"

    BindingCatalogModel {
        id: _catalog
        guid: device ? device.guid : ""
        deviceName: _root.claimDeviceName
    }

    Connections {
        target: moduleModel
        function onClaimsChanged() { _catalog.reload() }
        function onViewChanged() { loadCatalog() }
    }

    Connections {
        target: uiState
        function onModeChanged() {
            if (uiState)
                _catalog.setMode(uiState.currentMode)
        }
        function onDeviceChanged() {
            if (!uiState)
                return
            showHid(uiState.currentInputIndex)
        }
    }

    Component.onCompleted: {
        if (uiState)
            _catalog.setMode(uiState.currentMode)
        loadCatalog()
    }

    onClaimDeviceNameChanged: loadCatalog()

    DeviceLiveState {
        id: _liveState
        guid: device ? device.guid : ""
        deviceName: _root.claimDeviceName
        locked: editorLocked
        liveWhileActive: false
    }

    HighlightSpeedModel {
        id: _highlightSpeed
    }

    ColorDialog {
        id: _colorDlg
        title: "Choose color"
        onAccepted: {
            var c = selectedColor.toString()
            if (_colorTarget === "child") colorChild = c
            else if (_colorTarget === "selected") colorSelected = c
            else if (_colorTarget === "text") colorText = c
            else if (_colorTarget === "muted") colorMuted = c
            else if (_colorTarget === "live") colorLive = c
            else if (_colorTarget === "border") colorBorder = c
            else if (_colorTarget === "selectBorder") colorSelectBorder = c
            else if (_colorTarget === "editor") colorEditor = c
            else if (_colorTarget === "editorBorder") colorEditorBorder = c
            else colorParent = c
        }
    }

    function catalogPayload() {
        return {
            listPadding: listPadding,
            rowSpacing: rowSpacing,
            parentHeight: parentHeight,
            childHeight: childHeight,
            parentAlign: parentAlign,
            parentLeft: parentLeft,
            parentRight: parentRight,
            parentWidthPct: parentWidthPct,
            childAlign: childAlign,
            childLeft: childLeft,
            childRight: childRight,
            childWidthPct: childWidthPct,
            parentFont: parentFont,
            childFont: childFont,
            summaryFont: summaryFont,
            parentBold: parentBold,
            showChildren: showChildren,
            showLiveBars: showLiveBars,
            showLeds: showLeds,
            showSummary: showSummary,
            rowRadius: rowRadius,
            nameColW: nameColW,
            childNameColW: childNameColW,
            rowInnerPad: rowInnerPad,
            editorIndent: editorIndent,
            colorParent: colorParent,
            colorChild: colorChild,
            colorSelected: colorSelected,
            colorText: colorText,
            colorMuted: colorMuted,
            colorLive: colorLive,
            colorBorder: colorBorder,
            colorSelectBorder: colorSelectBorder,
            colorEditor: colorEditor,
            colorEditorBorder: colorEditorBorder
        }
    }

    function applyDefaults() {
        listPadding = 8
        rowSpacing = 4
        parentHeight = 50
        childHeight = 36
        parentAlign = "left"
        parentLeft = 0
        parentRight = 0
        parentWidthPct = 100
        childAlign = "left"
        childLeft = 24
        childRight = 24
        childWidthPct = 50
        parentFont = 13
        childFont = 12
        summaryFont = 12
        parentBold = true
        showChildren = true
        showLiveBars = true
        showLeds = true
        showSummary = true
        rowRadius = 3
        nameColW = 180
        childNameColW = 160
        rowInnerPad = 10
        editorIndent = 12
        colorParent = "#111113"
        colorChild = "#111113"
        colorSelected = "#27272A"
        colorText = "#E4E4E7"
        colorMuted = "#A1A1AA"
        colorLive = "#22C55E"
        colorBorder = "#3F3F46"
        colorSelectBorder = "#E4E4E7"
        colorEditor = "#0F2744"
        colorEditorBorder = "#3B82F6"
    }

    function numVal(v, d) {
        var n = Number(v)
        return (v === undefined || v === null || v === "" || isNaN(n)) ? d : n
    }

    function loadCatalog() {
        if (!moduleModel || !claimDeviceName.length)
            return
        try {
            var v = JSON.parse(moduleModel.catalogConfigJson(claimDeviceName))
        } catch (e) {
            return
        }
        listPadding = numVal(v.listPadding, 8)
        rowSpacing = numVal(v.rowSpacing, 4)
        parentHeight = numVal(v.parentHeight, 50)
        childHeight = numVal(v.childHeight, 36)
        parentAlign = v.parentAlign || "left"
        parentLeft = numVal(v.parentLeft, 0)
        parentRight = numVal(v.parentRight, 0)
        parentWidthPct = numVal(v.parentWidthPct, 100)
        childAlign = v.childAlign || "left"
        childLeft = numVal(v.childLeft, 24)
        childRight = numVal(v.childRight, 24)
        childWidthPct = numVal(v.childWidthPct, 50)
        parentFont = numVal(v.parentFont, 13)
        childFont = numVal(v.childFont, 12)
        summaryFont = numVal(v.summaryFont, 12)
        parentBold = v.parentBold !== false
        showChildren = v.showChildren !== false
        showLiveBars = v.showLiveBars !== false
        showLeds = v.showLeds !== false
        showSummary = v.showSummary !== false
        rowRadius = numVal(v.rowRadius, 3)
        nameColW = numVal(v.nameColW, 180)
        childNameColW = numVal(v.childNameColW, 160)
        rowInnerPad = numVal(v.rowInnerPad, 10)
        editorIndent = numVal(v.editorIndent, 12)
        colorParent = v.colorParent || "#111113"
        colorChild = v.colorChild || "#111113"
        colorSelected = v.colorSelected || "#27272A"
        colorText = v.colorText || "#E4E4E7"
        colorMuted = v.colorMuted || "#A1A1AA"
        colorLive = v.colorLive || "#22C55E"
        colorBorder = v.colorBorder || "#3F3F46"
        colorSelectBorder = v.colorSelectBorder || "#E4E4E7"
        colorEditor = v.colorEditor || "#0F2744"
        colorEditorBorder = v.colorEditorBorder || "#3B82F6"
    }

    function saveCatalog() {
        if (moduleModel && claimDeviceName.length)
            moduleModel.saveCatalogConfig(claimDeviceName, JSON.stringify(catalogPayload()))
        toastText = "Display Options Saved"
        _savedToast.open()
    }

    function resetCatalog() {
        applyDefaults()
        toastText = "Options have been reset"
        _savedToast.open()
    }

    function selectHid(hid) {
        if (!uiState || !device || hid < 0)
            return
        var ident = device.inputIdentifier(hid)
        if (!ident)
            return
        uiState.setCurrentInput(ident, hid)
    }

    function showHid(hid) {
        if (hid < 0)
            return
        let row = _catalog.rowForDeviceIndex(hid)
        if (row < 0)
            return
        if (_list.currentIndex !== row)
            _list.currentIndex = row
        Qt.callLater(function() {
            _list.positionViewAtIndex(row, ListView.Contain)
        })
    }

    function openEditor(hid) {
        if (hid < 0 || editorLocked)
            return
        selectHid(hid)
        _root.editingHid = hid
        showHid(hid)
    }

    function closeEditor() {
        _root.editingHid = -1
        _catalog.reload()
    }

    function rowX(total, align, left, right, pct) {
        var w = rowW(total, align, left, right, pct)
        if (align === "center")
            return Math.max(0, Math.round((total - w) / 2))
        if (align === "right")
            return Math.max(0, total - w - right)
        return left
    }

    function rowW(total, align, left, right, pct) {
        if (align === "center")
            return Math.max(120, Math.round(total * pct / 100))
        return Math.max(120, total - left - right)
    }

    function leafX(total) {
        return rowX(total, childAlign, childLeft, childRight, childWidthPct)
    }

    function leafW(total) {
        return rowW(total, childAlign, childLeft, childRight, childWidthPct)
    }

    function parentX(total) {
        return rowX(total, parentAlign, parentLeft, parentRight, parentWidthPct)
    }

    function parentW(total) {
        return rowW(total, parentAlign, parentLeft, parentRight, parentWidthPct)
    }

    Connections {
        target: signal
        function onSetInputIndex(index) { showHid(index) }
        function onInputItemChanged(itemIndex) {
            if (_root.editingHid >= 0)
                return
            _catalog.reload()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: listPadding
                Layout.rightMargin: listPadding
                Layout.topMargin: 8
                Label { text: "Type"; color: colorMuted }
                ComboBox {
                    id: _typeBox
                    Layout.preferredWidth: 180
                    model: ["All types", "Map to vJoy", "Map to keyboard", "Map to mouse", "Map to Xbox", "Macro", "Change mode", "Other", "Unmapped"]
                    onActivated: {
                        var tags = ["all", "vjoy", "keyboard", "mouse", "xbox", "macro", "mode", "other", "unmapped"]
                        _catalog.typeFilter = tags[currentIndex]
                    }
                }
                Label { text: "Destination"; color: colorMuted }
                ComboBox {
                    id: _destBox
                    Layout.fillWidth: true
                    model: _catalog.destChoices
                    onActivated: {
                        _catalog.destFilter = currentText === "All devices" ? "all" : currentText
                    }
                }
            }

            JGListView {
                id: _list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: listPadding
                Layout.rightMargin: listPadding
                scrollbarAlwaysVisible: true
                spacing: rowSpacing
                highlightFollowsCurrentItem: true
                highlightMoveDuration: {
                    if (!_highlightSpeed)
                        return 150
                    if (_highlightSpeed.speed === "Fast")
                        return 0
                    if (_highlightSpeed.speed === "Medium")
                        return 70
                    return 150
                }
                model: _catalog
                property int editingHid: _root.editingHid
                property bool catalogLocked: _root.editorLocked
                property bool catalogIsOutput: _root.isOutput
                property var live: _liveState
                property var catalogModel: _catalog
                property int parentH: _root.parentHeight
                property int childH: _root.childHeight
                property bool kidsOn: _root.showChildren
                property bool barsOn: _root.showLiveBars
                property bool ledsOn: _root.showLeds
                property bool summaryOn: _root.showSummary
                property int pFont: _root.parentFont
                property int cFont: _root.childFont
                property int sFont: _root.summaryFont
                property bool pBold: _root.parentBold
                property int rowRad: _root.rowRadius
                property int nameW: _root.nameColW
                property int childNameW: _root.childNameColW
                property int innerPad: _root.rowInnerPad
                property int edIndent: _root.editorIndent
                property color cParent: _root.colorParent
                property color cChild: _root.colorChild
                property color cSel: _root.colorSelected
                property color cText: _root.colorText
                property color cMuted: _root.colorMuted
                property color cLive: _root.colorLive
                property color cBorder: _root.colorBorder
                property color cSelBorder: _root.colorSelectBorder
                property color cEditor: _root.colorEditor
                property color cEditorEdge: _root.colorEditorBorder

                function addOnRow(hid, rowIndex) {
                    currentIndex = rowIndex
                    _root.selectHid(hid)
                    _catalog.addSequence(hid)
                    _root.editingHid = hid
                    _root.showHid(hid)
                }
                function okRow() { _root.closeEditor() }
                function openRow(hid) { _root.openEditor(hid) }

                delegate: Item {
                    id: _row
                    required property int index
                    required property string rowKind
                    required property string name
                    required property string summary
                    required property string typeLabel
                    required property string destLabel
                    required property string kind
                    required property int hwId
                    required property int deviceIndex
                    required property int bindingCount
                    required property int indent
                    property var lv: ListView.view
                    readonly property bool isLeaf: rowKind === "leaf"
                    width: lv.width - 12
                    readonly property bool isGroup: rowKind === "group" || rowKind === "unmapped"
                    readonly property bool expanded: isGroup && deviceIndex === lv.editingHid && deviceIndex >= 0
                    readonly property bool hideLeaf: isLeaf && (deviceIndex === lv.editingHid || !lv.kidsOn)
                    height: hideLeaf ? 0 : ((isLeaf ? lv.childH : lv.parentH) + (expanded ? _editor.height + 8 : 0))
                    visible: !hideLeaf

                    readonly property bool selected: index === lv.currentIndex || expanded
                    property int liveStamp: lv.live.stamp
                    property string inputKind: (liveStamp >= 0 && deviceIndex >= 0) ? lv.live.kindAt(deviceIndex) : ""
                    property real liveValue: (liveStamp >= 0 && deviceIndex >= 0) ? lv.live.valueAt(deviceIndex) : 0
                    readonly property bool ledOn: (inputKind === "button" || inputKind === "hat") && liveValue > 0.5
                    readonly property bool axisRow: kind === "axis"

                    Rectangle {
                        id: _header
                        x: isLeaf ? _root.leafX(_row.width) : _root.parentX(_row.width)
                        width: isLeaf ? _root.leafW(_row.width) : _root.parentW(_row.width)
                        height: isLeaf ? lv.childH : lv.parentH
                        radius: lv.rowRad
                        border.width: selected ? 2 : 1
                        border.color: selected ? lv.cSelBorder : lv.cBorder
                        color: {
                            if (ledOn)
                                return Qt.rgba(lv.cLive.r, lv.cLive.g, lv.cLive.b, selected ? 0.55 : 0.28)
                            if (selected)
                                return lv.cSel
                            if (rowKind === "unmapped-header")
                                return "#18181B"
                            return isLeaf ? lv.cChild : lv.cParent
                        }

                        Rectangle {
                            visible: lv.barsOn && axisRow && rowKind === "group"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 1
                            height: 5
                            color: lv.cBorder
                            Rectangle {
                                width: {
                                    liveStamp
                                    return Math.max(0, Math.min(parent.width, parent.width * ((liveValue + 1.0) * 0.5)))
                                }
                                height: parent.height
                                color: lv.cLive
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.rightMargin: expanded ? 120 : 64
                            enabled: deviceIndex >= 0
                            onClicked: {
                                lv.currentIndex = index
                                lv.syncSelection()
                                if (rowKind === "leaf")
                                    lv.openRow(deviceIndex)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: lv.innerPad
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                visible: lv.ledsOn && (kind === "button" || kind === "hat")
                                width: 10
                                height: 10
                                radius: 5
                                color: ledOn ? lv.cLive : lv.cBorder
                            }

                            Label {
                                text: rowKind === "leaf" ? typeLabel : name
                                color: lv.cText
                                font.bold: rowKind !== "leaf" && lv.pBold
                                font.pixelSize: rowKind === "leaf" ? lv.cFont : lv.pFont
                                elide: Text.ElideRight
                                Layout.preferredWidth: rowKind === "leaf" ? lv.childNameW : lv.nameW
                            }
                            Label {
                                visible: lv.summaryOn || rowKind === "leaf"
                                text: rowKind === "leaf" ? destLabel : (rowKind === "unmapped-header" ? summary : (rowKind === "unmapped" ? "Not bound" : summary))
                                color: lv.cMuted
                                font.pixelSize: lv.sFont
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                wrapMode: Text.NoWrap
                            }
                            Button {
                                visible: (rowKind === "group" || rowKind === "unmapped") && !lv.catalogLocked
                                text: "ADD"
                                implicitWidth: 56
                                implicitHeight: 28
                                z: 2
                                onClicked: lv.addOnRow(deviceIndex, index)
                            }
                            Button {
                                visible: expanded && !lv.catalogLocked
                                text: "OK"
                                implicitWidth: 56
                                implicitHeight: 28
                                z: 2
                                onClicked: lv.okRow()
                            }
                        }
                    }

                    Loader {
                        id: _editor
                        active: expanded
                        visible: expanded
                        x: lv.edIndent
                        y: lv.parentH + 4
                        width: parent.width - lv.edIndent
                        height: visible && item ? Math.max(80, item.implicitHeight) : 0
                        onLoaded: if (item) item.width = width
                        onWidthChanged: if (item) item.width = width
                        sourceComponent: InputConfiguration {
                            inlineMode: true
                            isOutput: lv.catalogIsOutput
                            editorFill: lv.cEditor
                            editorEdge: lv.cEditorEdge
                        }
                    }
                }

                function syncSelection() {
                    if (!uiState || !device || currentIndex < 0 || _root.editorLocked)
                        return
                    var hid = _catalog.deviceIndexAt(currentIndex)
                    if (hid < 0)
                        return
                    _root.selectHid(hid)
                }

                onCurrentIndexChanged: syncSelection()
            }

            Label {
                visible: _catalog.count === 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: colorMuted
                horizontalAlignment: Text.AlignHCenter
                text: "This window only shows what the input module passes.\nRight-click the card → Configure input module, press the controls to claim, then Save module."
            }
        }

        Rectangle {
            visible: _root.showPanel
            Layout.preferredWidth: 360
            Layout.maximumWidth: 360
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
                        text: "Configuration — Display"
                        color: "#E4E4E7"
                        font.bold: true
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                    Button {
                        text: "×"
                        implicitWidth: 28
                        onClicked: _root.closePanel()
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ColumnLayout {
                        width: 330
                        spacing: 12

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                color: "#27272A"
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "ROWS"
                                    color: "#E4E4E7"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            RowLayout {
                                Label { text: "Parent height"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 36; to: 80; value: parentHeight; onValueModified: parentHeight = value }
                            }
                            RowLayout {
                                Label { text: "Child height"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 24; to: 60; value: childHeight; onValueModified: childHeight = value }
                            }
                            RowLayout {
                                Label { text: "Spacing"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 16; value: rowSpacing; onValueModified: rowSpacing = value }
                            }
                            RowLayout {
                                Label { text: "List padding"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 32; value: listPadding; onValueModified: listPadding = value }
                            }
                            RowLayout {
                                Label { text: "Corner radius"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 16; value: rowRadius; onValueModified: rowRadius = value }
                            }
                            RowLayout {
                                Label { text: "Inner pad"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 32; value: rowInnerPad; onValueModified: rowInnerPad = value }
                            }
                            CheckBox { text: "Show child rows"; checked: showChildren; onToggled: showChildren = checked }
                            CheckBox { text: "Show live bars"; checked: showLiveBars; onToggled: showLiveBars = checked }
                            CheckBox { text: "Show LED dots"; checked: showLeds; onToggled: showLeds = checked }
                            CheckBox { text: "Show summary"; checked: showSummary; onToggled: showSummary = checked }
                        }

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                color: "#27272A"
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "PARENT ALIGNMENT"
                                    color: "#E4E4E7"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            RowLayout {
                                Label { text: "Align"; color: "#E4E4E7"; Layout.preferredWidth: 70 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: ["left", "center", "right"]
                                    currentIndex: parentAlign === "center" ? 1 : (parentAlign === "right" ? 2 : 0)
                                    onActivated: parentAlign = currentText
                                }
                            }
                            RowLayout {
                                visible: parentAlign !== "center"
                                Label { text: "Left inset"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 800; stepSize: 8; value: parentLeft; onValueModified: parentLeft = value }
                            }
                            RowLayout {
                                visible: parentAlign !== "center"
                                Label { text: "Right inset"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 800; stepSize: 8; value: parentRight; onValueModified: parentRight = value }
                            }
                            RowLayout {
                                visible: parentAlign === "center"
                                Label { text: "Width %"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 20; to: 100; value: parentWidthPct; onValueModified: parentWidthPct = value }
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                color: "#27272A"
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "CHILD ALIGNMENT"
                                    color: "#E4E4E7"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            RowLayout {
                                Label { text: "Align"; color: "#E4E4E7"; Layout.preferredWidth: 70 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: ["left", "center", "right"]
                                    currentIndex: childAlign === "center" ? 1 : (childAlign === "right" ? 2 : 0)
                                    onActivated: childAlign = currentText
                                }
                            }
                            RowLayout {
                                visible: childAlign !== "center"
                                Label { text: "Left inset"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 800; stepSize: 8; value: childLeft; onValueModified: childLeft = value }
                            }
                            RowLayout {
                                visible: childAlign !== "center"
                                Label { text: "Right inset"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 800; stepSize: 8; value: childRight; onValueModified: childRight = value }
                            }
                            RowLayout {
                                visible: childAlign === "center"
                                Label { text: "Width %"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 20; to: 100; value: childWidthPct; onValueModified: childWidthPct = value }
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                color: "#27272A"
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "TEXT"
                                    color: "#E4E4E7"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            RowLayout {
                                Label { text: "Parent size"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 10; to: 22; value: parentFont; onValueModified: parentFont = value }
                            }
                            RowLayout {
                                Label { text: "Child size"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 9; to: 20; value: childFont; onValueModified: childFont = value }
                            }
                            RowLayout {
                                Label { text: "Summary size"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 9; to: 20; value: summaryFont; onValueModified: summaryFont = value }
                            }
                            RowLayout {
                                Label { text: "Parent name col"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 80; to: 360; stepSize: 10; value: nameColW; onValueModified: nameColW = value }
                            }
                            RowLayout {
                                Label { text: "Child name col"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 80; to: 360; stepSize: 10; value: childNameColW; onValueModified: childNameColW = value }
                            }
                            CheckBox { text: "Bold parent names"; checked: parentBold; onToggled: parentBold = checked }
                        }

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                color: "#27272A"
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "EDITOR"
                                    color: "#E4E4E7"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            RowLayout {
                                Label { text: "Editor indent"; color: "#E4E4E7"; Layout.fillWidth: true }
                                SpinBox { from: 0; to: 80; value: editorIndent; onValueModified: editorIndent = value }
                            }
                            Label {
                                text: "Editor fill and edge colors are in COLORS."
                                color: "#A1A1AA"
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                color: "#27272A"
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "COLORS"
                                    color: "#E4E4E7"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Parent row"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "parent"; _colorDlg.selectedColor = colorParent; _colorDlg.open() }
                                    background: Rectangle { color: colorParent; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Child row"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "child"; _colorDlg.selectedColor = colorChild; _colorDlg.open() }
                                    background: Rectangle { color: colorChild; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Selected fill"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "selected"; _colorDlg.selectedColor = colorSelected; _colorDlg.open() }
                                    background: Rectangle { color: colorSelected; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Text"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "text"; _colorDlg.selectedColor = colorText; _colorDlg.open() }
                                    background: Rectangle { color: colorText; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Muted text"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "muted"; _colorDlg.selectedColor = colorMuted; _colorDlg.open() }
                                    background: Rectangle { color: colorMuted; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Live bar"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "live"; _colorDlg.selectedColor = colorLive; _colorDlg.open() }
                                    background: Rectangle { color: colorLive; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Border"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "border"; _colorDlg.selectedColor = colorBorder; _colorDlg.open() }
                                    background: Rectangle { color: colorBorder; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Select border"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "selectBorder"; _colorDlg.selectedColor = colorSelectBorder; _colorDlg.open() }
                                    background: Rectangle { color: colorSelectBorder; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Editor fill"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "editor"; _colorDlg.selectedColor = colorEditor; _colorDlg.open() }
                                    background: Rectangle { color: colorEditor; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Editor edge"; color: "#E4E4E7"; Layout.preferredWidth: 110 }
                                Button {
                                    Layout.fillWidth: true
                                    text: "Choose…"
                                    onClicked: { _colorTarget = "editorBorder"; _colorDlg.selectedColor = colorEditorBorder; _colorDlg.open() }
                                    background: Rectangle { color: colorEditorBorder; border.color: "#3F3F46"; border.width: 1; radius: 3 }
                                    contentItem: Label { text: parent.text; color: "#111111"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Button { text: "Reset"; onClicked: resetCatalog() }
                    Item { Layout.fillWidth: true }
                    Button { text: "Save with module"; highlighted: true; onClicked: saveCatalog() }
                }
            }
        }
    }

    Popup {
        id: _savedToast
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        dim: true
        Overlay.modal: Rectangle { color: "#66000000" }
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        padding: 18
        background: Rectangle {
            color: "#27272A"
            border.color: "#52525B"
            radius: 6
        }
        contentItem: Label {
            text: toastText
            color: "#F4F4F5"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
        }
        Timer {
            id: _savedTimer
            interval: 2000
            onTriggered: _savedToast.close()
        }
        onOpened: _savedTimer.restart()
        onClosed: _savedTimer.stop()
    }
}
