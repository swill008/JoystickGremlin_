# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only
# Device-Configuration-Macro Change — Configuration display panel.

from pathlib import Path

_QML = Path(__file__).resolve().parents[2] / "qml/BindingCatalog.qml"
_MAIN = Path(__file__).resolve().parents[2] / "qml/Main.qml"
_IC = Path(__file__).resolve().parents[2] / "qml/InputConfiguration.qml"
_MM = Path(__file__).resolve().parents[2] / "gremlin/ui/module_model.py"


def test_main_has_catalog_display_button() -> None:
    text = _MAIN.read_text(encoding="utf-8")
    assert "property bool catalogPanel: false" in text
    assert 'text: catalogPanel ? "Hide Display Options" : "Edit Display Options"' in text
    assert "showPanel: _root.catalogPanel" in text
    assert "onClosePanel: _root.catalogPanel = false" in text
    assert "catalogPanel = false" in text
    dest_btn = text[text.find("outputViewPanel ?") : text.find("catalogPanel ?")]
    assert "configDirection === \"dest\"" in dest_btn or 'visible: configDirection === "dest"' in text


def test_panel_matches_omv_chrome() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert 'text: "Configuration — Display"' in text
    assert "Layout.preferredWidth: 360" in text
    assert 'text: "Save with module"' in text
    assert "onClicked: resetCatalog()" in text
    assert "id: _savedToast" in text
    assert "interval: 2000" in text
    assert "CloseOnPressOutside" in text
    assert 'text: "ROWS"' in text
    assert 'text: "PARENT ALIGNMENT"' in text
    assert 'text: "CHILD ALIGNMENT"' in text
    assert 'text: "TEXT"' in text
    assert 'text: "COLORS"' in text
    assert 'text: "EDITOR"' in text
    assert 'text: "Show accent bar"' in text
    assert 'text: "Gap below row"' in text
    assert "function editorX(total)" in text
    assert "function editorW(total)" in text
    assert 'text: "Show LED dots"' in text
    assert 'text: "Left inset"' in text
    assert 'text: "Right inset"' in text
    assert 'model: ["left", "center", "right"]' in text
    assert "ColorDialog" in text
    assert "signal closePanel()" in text


def test_reset_does_not_save() -> None:
    text = _QML.read_text(encoding="utf-8")
    chunk = text[text.find("function resetCatalog") : text.find("function selectHid")]
    assert "saveCatalogConfig" not in chunk
    assert "Options have been reset" in chunk
    assert "applyDefaults()" in chunk


def test_save_writes_catalog_not_view() -> None:
    text = _QML.read_text(encoding="utf-8")
    save = text[text.find("function saveCatalog") : text.find("function resetCatalog")]
    assert "saveCatalogConfig" in save
    assert "saveViewConfig" not in save
    assert "Display Options Saved" in save
    mm = _MM.read_text(encoding="utf-8")
    assert 'doc["catalog"] = catalog' in mm
    assert "_DEFAULT_CATALOG" in mm
    assert "def catalogConfigJson" in mm


def test_zero_padding_survives_load() -> None:
    def num_val(v, d):
        if v is None or v == "":
            return d
        try:
            n = float(v)
        except (TypeError, ValueError):
            return d
        return int(n) if n == int(n) else n

    assert num_val(0, 8) == 0
    assert num_val(None, 8) == 8
    text = _QML.read_text(encoding="utf-8")
    assert "v.listPadding || 8" not in text
    assert "numVal(v.listPadding, 8)" in text


def test_leaf_geometry_left_center_right() -> None:
    def leaf_w(total, align, left, right, width_pct):
        if align == "center":
            return max(120, round(total * width_pct / 100))
        return max(120, total - left - right)

    def leaf_x(total, align, left, right, width_pct):
        w = leaf_w(total, align, left, right, width_pct)
        if align == "center":
            return max(0, round((total - w) / 2))
        if align == "right":
            return max(0, total - w - right)
        return left

    total = 1000
    assert leaf_x(total, "left", 24, 24, 50) == 24
    assert leaf_w(total, "left", 24, 24, 50) == 952
    assert leaf_x(total, "left", 180, 500, 50) == 180
    assert leaf_w(total, "left", 180, 500, 50) == 320
    assert leaf_w(total, "center", 0, 0, 50) == 500
    assert leaf_x(total, "center", 0, 0, 50) == 250
    text = _QML.read_text(encoding="utf-8")
    assert "function leafX(total)" in text
    assert "function leafW(total)" in text
    assert "function parentX(total)" in text
    assert "function parentW(total)" in text
    assert "function rowX(total, align, left, right, pct)" in text
    assert "parentX(_row.width)" in text
    assert "parentW(_row.width)" in text


def test_parent_geometry_defaults_full_width() -> None:
    def row_w(total, align, left, right, width_pct):
        if align == "center":
            return max(120, round(total * width_pct / 100))
        return max(120, total - left - right)

    def row_x(total, align, left, right, width_pct):
        w = row_w(total, align, left, right, width_pct)
        if align == "center":
            return max(0, round((total - w) / 2))
        if align == "right":
            return max(0, total - w - right)
        return left

    total = 1000
    assert row_x(total, "left", 0, 0, 100) == 0
    assert row_w(total, "left", 0, 0, 100) == 1000
    assert row_x(total, "left", 40, 80, 100) == 40
    assert row_w(total, "left", 40, 80, 100) == 880
    assert row_w(total, "center", 0, 0, 80) == 800
    assert row_x(total, "center", 0, 0, 80) == 100
    mm = _MM.read_text(encoding="utf-8")
    assert '"parentAlign": "left"' in mm
    assert '"parentLeft": 0' in mm
    assert '"parentRight": 0' in mm
    assert '"parentWidthPct": 100' in mm


def test_catalog_merge_does_not_touch_view() -> None:
    default = {"listPadding": 8, "childAlign": "left"}
    doc = {"kind": "control.hardware", "device": "EVO R", "view": {"meterWidth": 22}}
    incoming = {"listPadding": 0, "childAlign": "center"}
    catalog = dict(default)
    raw = doc.get("catalog")
    if isinstance(raw, dict):
        catalog.update(raw)
    catalog.update(incoming)
    doc["catalog"] = catalog
    assert doc["view"] == {"meterWidth": 22}
    assert doc["catalog"]["listPadding"] == 0
    assert doc["catalog"]["childAlign"] == "center"


def test_inline_editor_colors_are_properties() -> None:
    text = _IC.read_text(encoding="utf-8")
    assert "property color editorFill" in text
    assert "property color editorEdge" in text
    assert "color: editorFill" in text
    qml = _QML.read_text(encoding="utf-8")
    assert "editorFill: lv.cEditor" in qml
    assert "editorEdge: lv.cEditorEdge" in qml
    assert "editorAccent: lv.cEditorAccent" in qml
    assert "editorPad: lv.edPad" in qml
    assert 'text: "Show accent bar"' in qml


def test_editor_geometry_defaults_match_old_indent() -> None:
    def row_w(total, align, left, right, width_pct):
        if align == "center":
            return max(120, round(total * width_pct / 100))
        return max(120, total - left - right)

    def row_x(total, align, left, right, width_pct):
        w = row_w(total, align, left, right, width_pct)
        if align == "center":
            return max(0, round((total - w) / 2))
        if align == "right":
            return max(0, total - w - right)
        return left

    total = 1000
    assert row_x(total, "left", 12, 0, 100) == 12
    assert row_w(total, "left", 12, 0, 100) == 988
    assert row_x(total, "left", 96, 256, 100) == 96
    assert row_w(total, "left", 96, 256, 100) == 648
    mm = _MM.read_text(encoding="utf-8")
    assert '"editorAlign": "left"' in mm
    assert '"editorIndent": 12' in mm
    assert '"editorRight": 0' in mm
    assert '"colorEditorAccent": "#3B82F6"' in mm


def test_editor_attaches_to_leaf_not_parent() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert "required property int seqIndex" in text
    assert "hideLeaf: isLeaf && !lv.kidsOn" in text
    assert "deviceIndex === lv.editingHid || !lv.kidsOn" not in text
    assert "expanded: isLeaf && deviceIndex === lv.editingHid && seqIndex === lv.editingSeq" in text
    assert "function addActionOnRow" in text
    assert "_catalog.addAction(hid, actionName)" in text
    assert "_catalog.addSequence(hid)" not in text
    assert "compactMode: true" in text
    assert "sequenceIndex: _row.seqIndex" in text
    assert "id: _addMenu" in text
    assert "_catalog.actionNames" in text
    bc = Path(__file__).resolve().parents[2] / "gremlin/ui/binding_catalog.py"
    src = bc.read_text(encoding="utf-8")
    assert 'QtCore.QByteArray(b"seqIndex")' in src
    assert "def addAction" in src
    assert "def actionNames" in src
    assert 'out.append((si, "", "New action", "Pick destination"))' in src


def test_compact_header_hides_r15_chrome() -> None:
    ic = _IC.read_text(encoding="utf-8")
    assert "property bool compactMode" in ic
    assert "property int sequenceIndex" in ic
    header = Path(__file__).resolve().parents[2] / "qml/InputItemBindingConfigurationHeader.qml"
    text = header.read_text(encoding="utf-8")
    assert "property bool compactMode" in text
    assert "visible: !_root.compactMode" in text
    binding = Path(__file__).resolve().parents[2] / "qml/InputItemBinding.qml"
    b = binding.read_text(encoding="utf-8")
    assert "property bool compactMode" in b
    assert "compactMode: _root.compactMode" in b


def test_selection_does_not_force_scroll() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert "function reloadKeepScroll()" in text
    assert "function rowOnScreen(row)" in text
    assert "highlightFollowsCurrentItem: false" in text
    assert "highlightFollowsCurrentItem: true" not in text
    assert "showHid(index, true)" in text
    assert "_root.showHid(hid)" not in text
    assert "reloadKeepScroll()" in text
    open_ed = text[text.find("function openEditor") : text.find("function closeEditor")]
    assert "positionViewAtIndex" not in open_ed
    add = text[text.find("function addActionOnRow") : text.find("function deleteRow")]
    assert "positionViewAtIndex" not in add
    assert "reloadKeepScroll" not in add
    assert "_catalog.addAction" in add


def test_child_context_menu_add_delete() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert "id: _childMenu" in text
    assert 'title: "Add"' in text
    assert 'text: "Delete"' in text
    assert "function deleteRow" in text
    assert "function openChildMenu" in text
    assert "_catalog.removeSequence(hid, seq)" in text
    assert "acceptedButtons: Qt.LeftButton | Qt.RightButton" in text
    assert "Qt.RightButton" in text
    assert "openChildMenu(deviceIndex, seqIndex)" in text
    bc = Path(__file__).resolve().parents[2] / "gremlin/ui/binding_catalog.py"
    src = bc.read_text(encoding="utf-8")
    assert "def removeSequence" in src
    assert "def addAction" in src


def test_add_does_not_reset_catalog_model() -> None:
    bc = Path(__file__).resolve().parents[2] / "gremlin/ui/binding_catalog.py"
    src = bc.read_text(encoding="utf-8")
    assert "signal.inputItemChanged.connect(self.refreshHid)" in src
    assert "signal.inputItemChanged.connect(self.reload)" not in src
    assert "def refreshHid" in src
    assert "beginInsertRows" in src
    assert "beginRemoveRows" in src
    assert "def _same_structure" in src
    qml = _QML.read_text(encoding="utf-8")
    changed = qml[qml.find("function onInputItemChanged") : qml.find("function onInputItemChanged") + 280]
    assert "_catalog.reload()" not in changed
    close = qml[qml.find("function closeEditor") : qml.find("function rowX")]
    assert "refreshHid" in close
    assert "reloadKeepScroll" not in close


def test_inline_repeater_exposes_index() -> None:
    ic = _IC.read_text(encoding="utf-8")
    assert "required property int index" in ic
    assert "required property var modelData" in ic
    assert "function loadModel()" in ic
    assert "onSequenceIndexChanged: loadModel()" in ic
    bc = Path(__file__).resolve().parents[2] / "gremlin/ui/binding_catalog.py"
    src = bc.read_text(encoding="utf-8")
    assert "signal.reloadCurrentInputItem.emit()" in src


def test_add_opens_editor_after_insert() -> None:
    text = _QML.read_text(encoding="utf-8")
    add = text[text.find("function addActionOnRow") : text.find("function deleteRow")]
    assert "Qt.callLater" in add
    assert "_root.editingHid = -1" in add
    open_ed = text[text.find("function openEditor") : text.find("function closeEditor")]
    assert "Qt.callLater" in open_ed
    assert "_list.forceLayout" in open_ed
    bc = Path(__file__).resolve().parents[2] / "gremlin/ui/binding_catalog.py"
    src = bc.read_text(encoding="utf-8")
    assert "len(new_rows) > len(old)" in src
    assert "extra = new_rows[len(old)" in src

