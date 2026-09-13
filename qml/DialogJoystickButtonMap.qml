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

    readonly property string targetName: "VKBsim Gladiator EVO R"
    readonly property string stockImage: "qml/images/vkb_gladiator_rig.jpg"
    property int _nameTick: 0
    property bool editing: false
    property var liveNodes: []
    property var workNodes: []
    property string photoOverride: ""
    property string storedImage: stockImage
    property string liveImage: stockImage
    property string selectedId: ""
    property var selectedNode: null

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

    function cancelEdit() {
        editing = false
        workNodes = []
        selectedId = ""
        selectedNode = null
        applyImage(liveImage)
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

    Component.onCompleted: () => {
        if (_devices) {
            _devices.reload()
        }
        loadLive()
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
                    text: "control.hardware  " + _hw.path
                    color: "#A1A1AA"
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
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

                Repeater {
                    model: _devices

                    Item {
                        required property string guid
                        required property string name
                        required property string pairLabel
                        required property bool mapped

                        anchors.fill: parent
                        visible: _buttonMap.isTarget(guid, name)

                        onVisibleChanged: {
                            if (visible) {
                                _hasTarget.hit = true
                            }
                        }
                        Component.onCompleted: {
                            if (visible) {
                                _hasTarget.hit = true
                            }
                        }

                        JoystickButtonMapCard {
                            id: _card
                            anchors.fill: parent
                            deviceGuid: guid
                            title: _buttonMap.displayName(guid, name)
                            pairLabel: pairLabel
                            editing: _buttonMap.editing
                            editorNodes: _buttonMap.editing ? _buttonMap.workNodes : _buttonMap.liveNodes
                            photoOverride: _buttonMap.photoOverride

                            Connections {
                                target: _card.editorItem
                                function onSelectedChanged() {
                                    _buttonMap.applySelected()
                                }
                                function onNodesChanged() {
                                    _buttonMap.applySelected()
                                }
                            }

                            Component.onCompleted: _cardLoader.item = _card
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

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Label { text: "Chip"; font.bold: true; color: "#E4E4E7" }
                    Label {
                        text: selectedNode ? selectedNode.id : "(select a chip or hotspot)"
                        color: "#A1A1AA"
                    }

                    Label { text: "Name"; color: "#A1A1AA"; visible: selectedNode }
                    TextField {
                        Layout.fillWidth: true
                        visible: selectedNode && selectedNode.kind !== "plus" && selectedNode.kind !== "pair" && selectedNode.kind !== "axis_stack"
                        text: selectedNode && selectedNode.label ? selectedNode.label : ""
                        placeholderText: "blank = hardware id → dest"
                        onEditingFinished: {
                            if (selectedNode) {
                                selectedNode.label = text
                                if (_cardLoader.item && _cardLoader.item.editorItem)
                                    _cardLoader.item.editorItem.bump()
                            }
                        }
                    }

                    Label { text: "Hardware id"; color: "#A1A1AA"; visible: selectedNode && selectedNode.hwId !== undefined }
                    SpinBox {
                        visible: selectedNode && selectedNode.kind !== "plus" && selectedNode.kind !== "pair" && selectedNode.kind !== "axis_stack"
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
                            if (selectedNode) {
                                selectedNode.fontSize = value
                                if (_cardLoader.item && _cardLoader.item.editorItem)
                                    _cardLoader.item.editorItem.bump()
                            }
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

                    Label { text: "Idle color"; color: "#A1A1AA"; visible: selectedNode }
                    TextField {
                        Layout.fillWidth: true
                        visible: !!selectedNode
                        text: selectedNode && selectedNode.color ? selectedNode.color : "#18181B"
                        onEditingFinished: {
                            if (selectedNode) {
                                selectedNode.color = text
                                if (_cardLoader.item && _cardLoader.item.editorItem)
                                    _cardLoader.item.editorItem.bump()
                            }
                        }
                    }
                    Label { text: "Highlight color"; color: "#A1A1AA"; visible: selectedNode }
                    TextField {
                        Layout.fillWidth: true
                        visible: !!selectedNode
                        text: selectedNode && selectedNode.hlColor ? selectedNode.hlColor : "#14532D"
                        onEditingFinished: {
                            if (selectedNode) {
                                selectedNode.hlColor = text
                                if (_cardLoader.item && _cardLoader.item.editorItem)
                                    _cardLoader.item.editorItem.bump()
                            }
                        }
                    }

                    Button {
                        visible: !!selectedNode
                        text: "Add spine"
                        onClicked: {
                            var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (ed && selectedNode) {
                                ed.ensureMidSpine(selectedNode)
                                ed.bump()
                            }
                        }
                    }
                    Button {
                        visible: !!selectedNode
                        text: "Delete selected spine"
                        onClicked: {
                            var ed = _cardLoader.item ? _cardLoader.item.editorItem : null
                            if (ed) {
                                ed.deleteSelection()
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
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
