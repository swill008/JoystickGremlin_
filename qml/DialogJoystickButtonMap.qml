// -*- coding: utf-8; -*-
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import Gremlin.Device
import Gremlin.Style

Window {
    id: _buttonMap

    width: 1180
    height: 980
    minimumWidth: 880
    minimumHeight: 720

    color: Style.background
    Universal.theme: Style.theme

    title: "Joystick Button Map — VKBsim Gladiator EVO R"

    onClosing: (e) => {
        if (_allowClose || !editing)
            return
        if (!isDirty())
            return
        e.accepted = false
        _leaveDlg.kind = "close"
        _leaveDlg.open()
    }

    readonly property string targetName: "VKBsim Gladiator EVO R"
    readonly property string stockImage: "qml/images/vkb_gladiator_rig.jpg"
    property int _nameTick: 0
    property bool editing: false
    property var liveNodes: []
    property var workNodes: []
    property string photoOverride: ""
    property string storedImage: ""
    property string liveImage: ""
    property string selectedId: ""
    property var selectedNode: null
    property bool _allowClose: false

    ViewerDeviceModel { id: _devices }
    HardwareProfile { id: _hw }

    DeviceNames {
        id: _names
        onChanged: _buttonMap._nameTick++
    }

    function displayName(guid, name) {
        if (!_names) {
            return name
        }
        return _nameTick, _names.display(guid, name)
    }

    function isTarget(guid, name) {
        var raw = String(name || "")
        var shown = String(displayName(guid, raw) || "")
        if (raw === targetName || shown === targetName) {
            return true
        }
        var a = raw.toLowerCase()
        var b = shown.toLowerCase()
        if (a.indexOf("evo l") !== -1 || b.indexOf("evo l") !== -1) {
            return false
        }
        if (a.indexOf("ot l") !== -1 || b.indexOf("ot l") !== -1) {
            return false
        }
        function isRight(s) {
            return s.indexOf("gladiator") !== -1 && (s.indexOf("evo r") !== -1 || s.indexOf("ot r") !== -1)
        }
        return isRight(a) || isRight(b)
    }

    function parseDoc(text) {
        try {
            var d = JSON.parse(text)
            return (d && d.nodes) ? d : null
        } catch (e) {
            return null
        }
    }

    function applyImage(rel) {
        storedImage = rel && rel.length ? rel : stockImage
        photoOverride = _hw.imageUrl(storedImage)
    }

    function loadLive() {
        var text = _hw.load(targetName)
        var doc = parseDoc(text)
        if (!doc || !doc.nodes || !doc.nodes.length) {
            return false
        }
        liveNodes = JSON.parse(JSON.stringify(doc.nodes))
        liveImage = doc.image && doc.image.length ? doc.image : stockImage
        applyImage(liveImage)
        return true
    }

    function enterEdit() {
        if (!liveNodes.length) {
            loadLive()
        }
        if (!liveNodes.length) {
            return
        }
        workNodes = JSON.parse(JSON.stringify(liveNodes))
        applyImage(liveImage)
        editing = true
        selectedId = ""
        selectedNode = null
    }

    function saveEdit() {
        var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
        var nodes = (ed && ed.nodes && ed.nodes.length) ? ed.nodes : workNodes
        var image = storedImage.length ? storedImage : stockImage
        var doc = {
            kind: "control.hardware",
            device: targetName,
            image: image,
            imageWidth: 899,
            imageHeight: 920,
            nodes: nodes
        }
        if (_hw.save(targetName, JSON.stringify(doc))) {
            liveNodes = JSON.parse(JSON.stringify(nodes))
            liveImage = image
            applyImage(liveImage)
            editing = false
            workNodes = []
            selectedId = ""
            selectedNode = null
        }
    }

    function editorNodesNow() {
        var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
        if (ed && ed.nodes && ed.nodes.length)
            return ed.nodes
        return workNodes
    }

    function isDirty() {
        if (!editing)
            return false
        var image = storedImage.length ? storedImage : stockImage
        var live = liveImage.length ? liveImage : stockImage
        try {
            return JSON.stringify({ image: image, nodes: editorNodesNow() }) !== JSON.stringify({ image: live, nodes: liveNodes })
        } catch (e) {
            return true
        }
    }

    function discardEdit() {
        editing = false
        workNodes = []
        selectedId = ""
        selectedNode = null
        applyImage(liveImage)
    }

    function cancelEdit() {
        if (isDirty()) {
            _leaveDlg.kind = "cancel"
            _leaveDlg.open()
            return
        }
        discardEdit()
    }

    function confirmLeaveSave() {
        saveEdit()
        _leaveDlg.close()
        if (!editing && _leaveDlg.kind === "close") {
            _allowClose = true
            close()
        }
    }

    function confirmLeaveDiscard() {
        discardEdit()
        _leaveDlg.close()
        if (_leaveDlg.kind === "close") {
            _allowClose = true
            close()
        }
    }

    function currentNode() {
        var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
        if (ed && ed.selectedId) {
            return ed.nodeAt(ed.selectedId)
        }
        return null
    }

    function applySelected() {
        var n = currentNode()
        selectedNode = n
        selectedId = n ? n.id : ""
    }

    Component.onCompleted: {
        if (_devices) {
            _devices.reload()
        }
        if (!loadLive()) {
            liveImage = stockImage
            storedImage = stockImage
        }
    }

    Dialog {
        id: _leaveDlg
        property string kind: "cancel"
        title: "Unsaved changes"
        modal: true
        anchors.centerIn: parent
        width: 440
        standardButtons: Dialog.NoButton
        closePolicy: Popup.CloseOnEscape

        ColumnLayout {
            anchors.fill: parent
            spacing: 12
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#FBBF24"
                text: "Caution: you have unsaved editor changes. If you leave without Save, this work will be lost."
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#A1A1AA"
                text: "Save writes the control.hardware profile and the live map. Discard restores the last saved map."
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button {
                    text: "Stay"
                    onClicked: _leaveDlg.close()
                }
                Button {
                    text: "Discard"
                    onClicked: _buttonMap.confirmLeaveDiscard()
                }
                Button {
                    text: "Save"
                    highlighted: true
                    onClicked: _buttonMap.confirmLeaveSave()
                }
            }
        }

        onRejected: close()
    }

    function _ed() {
        return _cardLoader.item ? _cardLoader.item.editorItem : null
    }

    Menu {
        id: _groupMenu
        MenuItem { text: "Group selected"; onTriggered: { var e = _ed(); if (e) e.groupSelection() } }
        MenuItem { text: "Ungroup"; onTriggered: { var e = _ed(); if (e) e.ungroupSelection() } }
        MenuSeparator {}
        MenuItem { text: "Edit group"; onTriggered: { var e = _ed(); if (e) e.beginGroupEdit(e.selectedId) } }
        MenuItem { text: "Done editing group"; onTriggered: { var e = _ed(); if (e) e.endGroupEdit() } }
        MenuSeparator {}
        MenuItem { text: "Align left"; onTriggered: { var e = _ed(); if (e) e.setAlignH("left") } }
        MenuItem { text: "Align center"; onTriggered: { var e = _ed(); if (e) e.setAlignH("center") } }
        MenuItem { text: "Align right"; onTriggered: { var e = _ed(); if (e) e.setAlignH("right") } }
        MenuItem { text: "Free layout"; onTriggered: { var e = _ed(); if (e) e.setAlignH("free") } }
    }

    Menu {
        id: _leadMenu
        MenuItem { text: "Add straight spine"; onTriggered: { var e = _ed(); if (e && selectedNode) { e.ensureMidSpine(selectedNode); e.bump() } } }
        MenuItem { text: "Add curved spine"; onTriggered: { var e = _ed(); if (e && selectedNode) e.addCurveSpine(selectedNode) } }
        MenuItem { text: "This segment curved"; onTriggered: { var e = _ed(); if (e) e.setSegCurve(e.currentLeader(e.nodeAt(e.selectedId)), Math.max(0, e.selectedSeg), true) } }
        MenuItem { text: "This segment straight"; onTriggered: { var e = _ed(); if (e) e.setSegCurve(e.currentLeader(e.nodeAt(e.selectedId)), Math.max(0, e.selectedSeg), false) } }
        MenuItem { text: "All segments curved"; onTriggered: { var e = _ed(); if (e) e.setAllSegCurve(true) } }
        MenuItem { text: "All segments straight"; onTriggered: { var e = _ed(); if (e) e.setAllSegCurve(false) } }
        MenuSeparator {}
        MenuItem { text: "Add leader (same chip / hotspot)"; onTriggered: { var e = _ed(); if (e) e.addLeader() } }
        MenuItem { text: "Branch from this end"; onTriggered: { var e = _ed(); if (e) e.addBranch() } }
        MenuItem { text: "Delete extra leader"; onTriggered: { var e = _ed(); if (e) e.deleteLeader() } }
        MenuSeparator {}
        MenuItem { text: "Detach chip end"; onTriggered: { var e = _ed(); if (e) e.detachEnd("from") } }
        MenuItem { text: "Detach hotspot end"; onTriggered: { var e = _ed(); if (e) e.detachEnd("to") } }
        MenuItem { text: "Reconnect to this chip"; onTriggered: { var e = _ed(); if (e) e.attachEndToSelf("from") } }
        MenuItem { text: "Reconnect to this hotspot"; onTriggered: { var e = _ed(); if (e) e.attachEndToSelf("to") } }
        MenuItem { text: "Delete selected spine"; onTriggered: { var e = _ed(); if (e) e.deleteSelection() } }
    }

    Menu {
        id: _chipMenu
        MenuItem {
            text: "Reservoir…"
            onTriggered: {
                _resPop.refresh()
                _resPop.open()
            }
        }
    }

    Popup {
        id: _resPop
        modal: false
        dim: false
        x: 12
        y: 52
        width: 360
        height: Math.min(560, _buttonMap.height - 80)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property var items: []
        property bool unusedOnly: false
        function refresh() {
            var e = _ed()
            items = e ? e.catalog() : []
        }
        background: Rectangle {
            color: "#111113"
            border.color: "#3F3F46"
            radius: 6
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            Label {
                text: "Chiplet reservoir"
                font.bold: true
                color: "#E4E4E7"
            }
            Label {
                text: "Every hardware control. Add places it at the view center. Already-on-map rows select it."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#A1A1AA"
                font.pixelSize: 11
            }
            CheckBox {
                text: "Unused only"
                checked: _resPop.unusedOnly
                onToggled: _resPop.unusedOnly = checked
            }
            ListView {
                id: _resList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: _resPop.items
                delegate: Rectangle {
                    required property var modelData
                    width: _resList.width
                    height: visible ? (_row.implicitHeight + 10) : 0
                    visible: !_resPop.unusedOnly || !modelData.placed
                    color: modelData.placed ? "#18181B" : "#0C0C0E"
                    border.color: modelData.placed ? "#3F3F46" : "#14532D"
                    radius: 4
                    ColumnLayout {
                        id: _row
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 6
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: modelData.friendly
                                color: "#F4F4F5"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Button {
                                text: modelData.placed ? "Select" : "Add"
                                implicitHeight: 24
                                onClicked: {
                                    var e = _ed()
                                    if (!e)
                                        return
                                    if (modelData.placed)
                                        e.setSelection([modelData.placedId])
                                    else
                                        e.addChiplet(modelData.kind, modelData.hwId)
                                    _resPop.refresh()
                                }
                            }
                        }
                        Label {
                            text: modelData.fullName
                            color: "#A1A1AA"
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: _imageDialog
        title: "Choose background image"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            var rel = _hw.copyImage(selectedFile, targetName)
            if (rel.length) {
                applyImage(rel)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolBar {
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                Button {
                    text: editing ? "Editing" : "Edit"
                    enabled: !editing
                    onClicked: enterEdit()
                }
                Button {
                    text: "Save"
                    visible: editing
                    onClicked: saveEdit()
                }
                Button {
                    text: "Cancel"
                    visible: editing
                    onClicked: cancelEdit()
                }
                ToolSeparator { visible: editing }
                Button {
                    visible: editing
                    text: "Group"
                    onClicked: _groupMenu.popup()
                }
                Button {
                    visible: editing
                    text: "Leader"
                    onClicked: _leadMenu.popup()
                }
                Button {
                    visible: editing
                    text: "Chiplets"
                    onClicked: _chipMenu.popup()
                }
                ToolSeparator { visible: editing }
                Button {
                    text: "Image…"
                    visible: editing
                    onClicked: _imageDialog.open()
                }
                Button {
                    text: "Clear image"
                    visible: editing
                    onClicked: {
                        _hw.clearImage(targetName)
                        applyImage(stockImage)
                    }
                }
                Label {
                    visible: editing
                    text: _cardLoader.item ? (Math.round(_cardLoader.item.zoom * 100) + "%") : "100%"
                    color: "#E4E4E7"
                    font.pixelSize: 12
                }
                Button {
                    visible: editing
                    text: "Reset view"
                    enabled: _cardLoader.item && Math.abs(_cardLoader.item.zoom - 1) > 0.02
                    onClicked: {
                        if (_cardLoader.item)
                            _cardLoader.item.resetView()
                    }
                }
                ToolSeparator { visible: editing }
                CheckBox {
                    visible: editing
                    text: "Grid"
                    checked: {
                        var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                        return e ? e.gridOn : true
                    }
                    onToggled: {
                        var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                        if (e)
                            e.gridOn = checked
                    }
                }
                CheckBox {
                    visible: editing
                    text: "Snap"
                    checked: {
                        var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                        return e ? e.snapOn : true
                    }
                    onToggled: {
                        var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                        if (e)
                            e.snapOn = checked
                    }
                }
                CheckBox {
                    visible: editing
                    text: "Auto pan"
                    checked: {
                        var c = _cardLoader.item
                        if (!c)
                            return false
                        return c.autoPanOn === true
                    }
                    onToggled: {
                        var c = _cardLoader.item
                        if (c)
                            c.autoPanOn = checked
                    }
                }
                Label {
                    visible: editing
                    text: "Size"
                    color: "#A1A1AA"
                }
                SpinBox {
                    visible: editing
                    from: 4
                    to: 64
                    stepSize: 2
                    editable: true
                    value: {
                        var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                        return e ? e.gridSize : 8
                    }
                    onValueModified: {
                        var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                        if (e)
                            e.gridSize = value
                    }
                }
                Label {
                    visible: editing
                    text: "control.hardware  " + _hw.path
                    color: "#A1A1AA"
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Shortcut {
                    enabled: editing
                    sequence: "Ctrl+0"
                    onActivated: {
                        if (_cardLoader.item)
                            _cardLoader.item.resetView()
                    }
                }
                Item { Layout.fillWidth: true; visible: !editing }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                JGText {
                    anchors.centerIn: parent
                    visible: !_hasTarget.hit
                    text: "Connect VKBsim Gladiator EVO R"
                    opacity: 0.65
                }

                QtObject {
                    id: _hasTarget
                    property bool hit: false
                }

                Component {
                    id: _cardComp
                    JoystickButtonMapCard {
                        id: _card
                        anchors.fill: parent
                        deviceGuid: parent.dGuid
                        title: _buttonMap.displayName(parent.dGuid, parent.dName)
                        pairLabel: parent.dPair
                        editing: _buttonMap.editing
                        editorNodes: _buttonMap.editing ? _buttonMap.workNodes : _buttonMap.liveNodes
                        photoOverride: _buttonMap.photoOverride
                        Connections {
                            target: _card.editorItem
                            function onSelectedChanged() { _buttonMap.applySelected() }
                            function onNodesChanged() { _buttonMap.applySelected() }
                        }
                        Component.onCompleted: _cardLoader.item = _card
                    }
                }

                Repeater {
                    model: _devices
                    Loader {
                        id: _slot
                        required property string guid
                        required property string name
                        required property string pairLabel
                        required property bool mapped
                        anchors.fill: parent
                        active: _buttonMap.isTarget(guid, name)
                        visible: active
                        property string dGuid: guid
                        property string dName: name
                        property string dPair: pairLabel
                        sourceComponent: _cardComp
                        onActiveChanged: if (active) _hasTarget.hit = true
                        onLoaded: {
                            _hasTarget.hit = true
                            _cardLoader.item = item
                        }
                    }
                }

                QtObject {
                    id: _cardLoader
                    property var item: null
                }
            }

            Rectangle {
                visible: editing
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: "#111113"
                border.color: "#27272A"

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth: width
                    contentHeight: _insp.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: _insp
                        width: parent.width
                        spacing: 8

                    Label { text: "Chip"; font.bold: true; color: "#E4E4E7" }
                    Label {
                        text: {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            var n = e && e.selectedIds ? e.selectedIds.length : 0
                            if (n > 1)
                                return n + " selected"
                            return selectedNode ? selectedNode.id : "(select a chip or hotspot)"
                        }
                        color: "#A1A1AA"
                    }
                    Label {
                        visible: !!selectedNode
                        color: "#71717A"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        text: "Group / Leader actions are in the toolbar menus (and right-click)."
                        font.pixelSize: 11
                    }
                    Shortcut {
                        enabled: editing
                        sequence: "Ctrl+G"
                        onActivated: {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e)
                                e.groupSelection()
                        }
                    }
                    Shortcut {
                        enabled: editing
                        sequence: "Ctrl+Shift+G"
                        onActivated: {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e)
                                e.ungroupSelection()
                        }
                    }

                    Label { text: "Full name"; color: "#A1A1AA"; visible: selectedNode }
                    Label {
                        visible: selectedNode
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: "#E4E4E7"
                        font.pixelSize: 12
                        text: {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            var n = selectedNode
                            if (!n || !e)
                                return ""
                            if (n.members && n.members.length) {
                                var parts = []
                                var lk = n.kind === "axis_stack" ? "axis" : "btn"
                                for (var i = 0; i < n.members.length; i++)
                                    parts.push(e.fullNameOf(lk, n.members[i].hwId))
                                return parts.join("\n")
                            }
                            return e.fullNameOf(n.kind, n.hwId)
                        }
                    }

                    Label { text: "Friendly name"; color: "#A1A1AA"; visible: selectedNode }
                    TextField {
                        Layout.fillWidth: true
                        visible: !!selectedNode
                        text: selectedNode && selectedNode.friendly ? selectedNode.friendly : (selectedNode && selectedNode.label ? selectedNode.label : "")
                        placeholderText: "shown on the chip"
                        onEditingFinished: {
                            if (selectedNode) {
                                selectedNode.friendly = text
                                selectedNode.label = text
                                if (_cardLoader.item && _cardLoader.item.editorItem)
                                    _cardLoader.item.editorItem.bump()
                            }
                        }
                    }

                    Label {
                        text: "Group align"
                        color: "#A1A1AA"
                        visible: selectedNode && (selectedNode.kind === "plus" || selectedNode.kind === "pair" || selectedNode.kind === "axis_stack" || selectedNode.kind === "stack")
                    }
                    RowLayout {
                        visible: selectedNode && (selectedNode.kind === "plus" || selectedNode.kind === "pair" || selectedNode.kind === "axis_stack" || selectedNode.kind === "stack")
                        Layout.fillWidth: true
                        spacing: 4
                        Button {
                            text: "Left"
                            checkable: true
                            checked: selectedNode && selectedNode.alignH === "left"
                            onClicked: { var e = _ed(); if (e) e.setAlignH("left") }
                        }
                        Button {
                            text: "Center"
                            checkable: true
                            checked: !selectedNode || !selectedNode.alignH || selectedNode.alignH === "center"
                            onClicked: { var e = _ed(); if (e) e.setAlignH("center") }
                        }
                        Button {
                            text: "Right"
                            checkable: true
                            checked: selectedNode && selectedNode.alignH === "right"
                            onClicked: { var e = _ed(); if (e) e.setAlignH("right") }
                        }
                        Button {
                            text: "Free"
                            checkable: true
                            checked: selectedNode && selectedNode.alignH === "free"
                            onClicked: { var e = _ed(); if (e) e.setAlignH("free") }
                        }
                    }

                    Label { text: "Hardware id"; color: "#A1A1AA"; visible: selectedNode && selectedNode.hwId !== undefined }
                    SpinBox {
                        visible: selectedNode && selectedNode.kind !== "plus" && selectedNode.kind !== "pair" && selectedNode.kind !== "axis_stack" && selectedNode.kind !== "stack"
                        from: 1
                        to: 64
                        value: selectedNode && selectedNode.hwId ? selectedNode.hwId : 1
                        onValueModified: {
                            if (selectedNode) {
                                selectedNode.hwId = value
                                if (_cardLoader.item && _cardLoader.item.editorItem)
                                    _cardLoader.item.editorItem.bump()
                            }
                        }
                    }

                    Label { text: "Font size"; color: "#A1A1AA"; visible: selectedNode }
                    SpinBox {
                        visible: !!selectedNode
                        from: 8
                        to: 22
                        value: selectedNode && selectedNode.fontSize ? selectedNode.fontSize : 10
                        onValueModified: {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e) e.applyField("fontSize", value)
                        }
                    }

                    Label { text: "Chip size"; color: "#A1A1AA"; visible: selectedNode }
                    SpinBox {
                        visible: !!selectedNode
                        from: 12
                        to: 48
                        value: selectedNode && selectedNode.chipSize ? selectedNode.chipSize : 18
                        onValueModified: {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e) e.applyField("chipSize", value)
                        }
                    }
                    Label { text: "Chip shape"; color: "#A1A1AA"; visible: selectedNode }
                    ComboBox {
                        Layout.fillWidth: true
                        visible: !!selectedNode
                        model: ["Round", "Square"]
                        currentIndex: selectedNode && selectedNode.chipShape === "square" ? 1 : 0
                        onActivated: (idx) => {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e) e.applyField("chipShape", idx === 1 ? "square" : "round")
                        }
                    }
                    Label { text: "Chip fill"; color: "#A1A1AA"; visible: selectedNode }
                    ComboBox {
                        Layout.fillWidth: true
                        visible: !!selectedNode
                        model: ["Filled", "Hollow"]
                        currentIndex: selectedNode && selectedNode.chipFill === "hollow" ? 1 : 0
                        onActivated: (idx) => {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e) e.applyField("chipFill", idx === 1 ? "hollow" : "filled")
                        }
                    }

                    Label { text: "Hotspot size"; color: "#A1A1AA"; visible: selectedNode }
                    SpinBox {
                        visible: !!selectedNode
                        from: 4
                        to: 28
                        value: selectedNode && selectedNode.hotSize ? selectedNode.hotSize : 9
                        onValueModified: {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e) e.applyField("hotSize", value)
                        }
                    }
                    Label { text: "Hotspot shape"; color: "#A1A1AA"; visible: selectedNode }
                    ComboBox {
                        Layout.fillWidth: true
                        visible: !!selectedNode
                        model: ["Round", "Square"]
                        currentIndex: selectedNode && selectedNode.hotShape === "square" ? 1 : 0
                        onActivated: (idx) => {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e) e.applyField("hotShape", idx === 1 ? "square" : "round")
                        }
                    }
                    Label { text: "Hotspot fill"; color: "#A1A1AA"; visible: selectedNode }
                    ComboBox {
                        Layout.fillWidth: true
                        visible: !!selectedNode
                        model: ["Filled", "Hollow"]
                        currentIndex: selectedNode && selectedNode.hotFill === "hollow" ? 1 : 0
                        onActivated: (idx) => {
                            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (e) e.applyField("hotFill", idx === 1 ? "hollow" : "filled")
                        }
                    }

                    CheckBox {
                        visible: !!selectedNode
                        text: "Highlight on press"
                        checked: selectedNode ? selectedNode.highlight !== false : true
                        onToggled: {
                            if (selectedNode) {
                                selectedNode.highlight = checked
                                if (_cardLoader.item && _cardLoader.item.editorItem)
                                    _cardLoader.item.editorItem.bump()
                            }
                        }
                    }

                    Label { text: "Colors"; color: "#A1A1AA"; visible: selectedNode }
                    GridLayout {
                        visible: !!selectedNode
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 6
                        Label { text: "Fill"; color: "#A1A1AA" }
                        ColorSwatch {
                            hex: selectedNode && selectedNode.color ? selectedNode.color : "#18181B"
                            onPicked: _colorPop.openField("color", hex, this)
                        }
                        Label { text: "Border"; color: "#A1A1AA" }
                        ColorSwatch {
                            hex: selectedNode && selectedNode.border ? selectedNode.border : "#3F3F46"
                            onPicked: _colorPop.openField("border", hex, this)
                        }
                        Label { text: "Text"; color: "#A1A1AA" }
                        ColorSwatch {
                            hex: selectedNode && selectedNode.textColor ? selectedNode.textColor : "#E4E4E7"
                            onPicked: _colorPop.openField("textColor", hex, this)
                        }
                        Label { text: "Highlight"; color: "#A1A1AA" }
                        ColorSwatch {
                            hex: selectedNode && selectedNode.hlColor ? selectedNode.hlColor : "#14532D"
                            onPicked: _colorPop.openField("hlColor", hex, this)
                        }
                        Label { text: "HL border"; color: "#A1A1AA" }
                        ColorSwatch {
                            hex: selectedNode && selectedNode.hlBorder ? selectedNode.hlBorder : "#22C55E"
                            onPicked: _colorPop.openField("hlBorder", hex, this)
                        }
                        Label { text: "HL text"; color: "#A1A1AA" }
                        ColorSwatch {
                            hex: selectedNode && selectedNode.hlText ? selectedNode.hlText : "#BBF7D0"
                            onPicked: _colorPop.openField("hlText", hex, this)
                        }
                    }

                    Label {
                        visible: !!selectedNode
                        color: "#71717A"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        text: "Double-click a leader segment to switch curve/straight."
                    }

                    Label {
                        text: "Save is the live map.\nCancel drops this session."
                        color: "#71717A"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font.pixelSize: 10
                    }
                    }
                }
            }
        }
    }

    component ColorSwatch: Rectangle {
        id: _sw
        property string hex: "#18181B"
        signal picked()
        Layout.preferredWidth: 72
        Layout.preferredHeight: 24
        width: 72
        height: 24
        radius: 4
        color: hex
        border.color: "#52525B"
        border.width: 1
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: _sw.picked()
        }
    }

    function _toHex(c) {
        var r = Math.round(c.r * 255)
        var g = Math.round(c.g * 255)
        var b = Math.round(c.b * 255)
        if (r < 0) r = 0
        if (r > 255) r = 255
        if (g < 0) g = 0
        if (g > 255) g = 255
        if (b < 0) b = 0
        if (b > 255) b = 255
        var rs = r.toString(16)
        var gs = g.toString(16)
        var bs = b.toString(16)
        if (rs.length < 2) rs = "0" + rs
        if (gs.length < 2) gs = "0" + gs
        if (bs.length < 2) bs = "0" + bs
        return "#" + rs + gs + bs
    }

    Popup {
        id: _colorPop
        parent: _buttonMap.contentItem
        width: 248
        height: 330
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 10
        property string field: "color"
        property real hh: 0
        property real ss: 0
        property real vv: 0.12
        readonly property color live: Qt.hsva(hh, ss, vv, 1)
        background: Rectangle {
            color: "#18181B"
            border.color: "#3F3F46"
            radius: 8
        }

        function openField(field, hex, anchorItem) {
            _colorPop.field = field
            var c = Qt.color(hex && hex.length ? hex : "#18181B")
            hh = c.hsvHue < 0 ? 0 : c.hsvHue
            ss = c.hsvSaturation
            vv = c.hsvValue
            if (anchorItem && parent) {
                var p = anchorItem.mapToItem(parent, 0, anchorItem.height + 4)
                x = Math.max(8, Math.min(parent.width - width - 8, p.x - width + anchorItem.width))
                y = Math.max(8, Math.min(parent.height - height - 8, p.y))
            }
            open()
        }

        function pushLive() {
            if (!visible)
                return
            var e = _cardLoader.item ? _cardLoader.item.editorItem : null
            if (e)
                e.applyField(field, _buttonMap._toHex(live))
        }

        onHhChanged: pushLive()
        onSsChanged: pushLive()
        onVvChanged: pushLive()

        ColumnLayout {
            anchors.fill: parent
            spacing: 8
            Label {
                text: "Pick color"
                color: "#E4E4E7"
                font.bold: true
            }
            Item {
                id: _sv
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#FFFFFF" }
                        GradientStop { position: 1; color: Qt.hsva(_colorPop.hh, 1, 1, 1) }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: 1; color: "#FF000000" }
                    }
                }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "transparent"
                    border.color: "#FFFFFF"
                    border.width: 2
                    x: _colorPop.ss * _sv.width - 6
                    y: (1 - _colorPop.vv) * _sv.height - 6
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 4
                        color: "transparent"
                        border.color: "#111111"
                        border.width: 1
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function take(mx, my) {
                        _colorPop.ss = Math.max(0, Math.min(1, mx / Math.max(1, _sv.width)))
                        _colorPop.vv = Math.max(0, Math.min(1, 1 - my / Math.max(1, _sv.height)))
                    }
                    onPressed: (m) => take(m.x, m.y)
                    onPositionChanged: (m) => { if (pressed) take(m.x, m.y) }
                }
            }
            Item {
                id: _hue
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#FF0000" }
                        GradientStop { position: 0.17; color: "#FFFF00" }
                        GradientStop { position: 0.33; color: "#00FF00" }
                        GradientStop { position: 0.50; color: "#00FFFF" }
                        GradientStop { position: 0.67; color: "#0000FF" }
                        GradientStop { position: 0.83; color: "#FF00FF" }
                        GradientStop { position: 1.0; color: "#FF0000" }
                    }
                }
                Rectangle {
                    width: 6
                    height: parent.height + 4
                    y: -2
                    x: _colorPop.hh * _hue.width - 3
                    radius: 2
                    color: "transparent"
                    border.color: "#FFFFFF"
                    border.width: 2
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function take(mx) {
                        _colorPop.hh = Math.max(0, Math.min(1, mx / Math.max(1, _hue.width)))
                    }
                    onPressed: (m) => take(m.x)
                    onPositionChanged: (m) => { if (pressed) take(m.x) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    width: 36
                    height: 24
                    radius: 4
                    color: _colorPop.live
                    border.color: "#52525B"
                }
                Label {
                    Layout.fillWidth: true
                    text: _buttonMap._toHex(_colorPop.live)
                    color: "#E4E4E7"
                    font.family: "Consolas"
                    font.pixelSize: 13
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: ["#18181B", "#3F3F46", "#E4E4E7", "#14532D", "#22C55E", "#BBF7D0", "#1D4ED8", "#7C2D12", "#831843", "#0F766E", "#FBBF24", "#000000", "#FFFFFF", "#7F1D1D"]
                    Rectangle {
                        required property string modelData
                        width: 16
                        height: 16
                        radius: 3
                        color: modelData
                        border.color: "#52525B"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var c = Qt.color(modelData)
                                _colorPop.hh = c.hsvHue < 0 ? 0 : c.hsvHue
                                _colorPop.ss = c.hsvSaturation
                                _colorPop.vv = c.hsvValue
                            }
                        }
                    }
                }
            }
        }
    }
}
