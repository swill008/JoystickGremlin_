# -*- coding: utf-8; -*-
# Device-Configuration-Macro Change — add / remove / leaf coverage.

from __future__ import annotations

from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]
_BC = _ROOT / "gremlin/ui/binding_catalog.py"
_QML = _ROOT / "qml/BindingCatalog.qml"
_IC = _ROOT / "qml/InputConfiguration.qml"
_HEADER = _ROOT / "qml/InputItemBindingConfigurationHeader.qml"

# Plugin .name values from action_plugins/*/__init__.py on this branch.
_PLUGIN_NAMES = [
    "Map to vJoy",
    "Map to Keyboard",
    "Map to Mouse",
    "Map to Xbox",
    "Map to Logical Device",
    "Macro",
    "Change Mode",
    "Load Profile",
    "Text to Speech",
    "Run Command",
    "Play Sound",
    "Response Curve",
    "Merge Axis",
    "Split Axis",
    "Axis Delta",
    "Dual Axis Deadzone",
    "Hat as Buttons",
    "Pause and Resume",
    "Chain",
    "Tempo",
    "Condition",
    "Double Tap",
    "Smart Toggle",
    "Description",
    "Reference",
]

_PLUGIN_TAGS = [
    "map-to-vjoy",
    "map-to-keyboard",
    "map-to-mouse",
    "map-to-xbox",
    "map-to-logical-device",
    "macro",
    "change-mode",
    "load-profile",
    "text-to-speech",
    "run-command",
    "play-sound",
    "response-curve",
    "merge-axis",
    "split-axis",
    "axis-delta",
    "dual-axis-deadzone",
    "hat-buttons",
    "pause-resume",
    "chain",
    "tempo",
    "condition",
    "double-tap",
    "smart-toggle",
    "description",
    "reference",
]


class _Act:
    def __init__(self, tag, name=None, children=None, **kw):
        self.tag = tag
        self.name = name or tag
        self.children = list(children or [])
        for k, v in kw.items():
            setattr(self, k, v)

    def get_actions(self):
        return list(self.children), []


class _Seq:
    def __init__(self, root):
        self.root_action = root


class _Item:
    def __init__(self):
        self.action_sequences = []

    def add_item_binding(self):
        root = _Act("root", name="Root", children=[])
        seq = _Seq(root)
        self.action_sequences.append(seq)

        class _Binding:
            root_action = root

            def insert_action(self, action, where):
                root.children.append(action)

        return _Binding()

    def remove_item_binding(self, seq):
        self.action_sequences.remove(seq)


def _load_helpers():
    """Load catalog helpers without importing PySide6."""
    src = _BC.read_text(encoding="utf-8")
    start = src.index("_WRAPPERS = {")
    end = src.index("@ta.QmlElement")
    ns: dict = {
        "InputType": type("InputType", (), {"JoystickButton": 1}),
        "common": type("common", (), {"input_to_ui_string": staticmethod(lambda t, i: f"Button {i}")}),
    }
    exec(src[start:end], ns)
    return ns


def test_summarize_covers_every_plugin_tag() -> None:
    ns = _load_helpers()
    labels = ns["_TYPE_LABELS"]
    wrappers = ns["_WRAPPERS"]
    for tag in _PLUGIN_TAGS:
        if tag == "root":
            continue
        assert tag in labels or tag in wrappers, tag
        act = _Act(tag, vjoy_device_id=1, vjoy_input_id=1, keys=["A"])
        lab, dest = ns["summarize_action"](act)
        assert lab
        assert dest


def test_collect_leaves_root_with_each_dest_action() -> None:
    ns = _load_helpers()
    dest_tags = [t for t in _PLUGIN_TAGS if t not in ns["_WRAPPERS"] and t != "root"]
    item = _Item()
    for tag in dest_tags:
        binding = item.add_item_binding()
        binding.insert_action(_Act(tag, vjoy_device_id=1, vjoy_input_id=3), "children")
    leaves = ns["leaves_for_item"](item)
    assert len(leaves) == len(dest_tags)
    tags = [t for _si, t, _l, _d in leaves]
    assert tags == dest_tags
    seqs = [si for si, _t, _l, _d in leaves]
    assert seqs == list(range(len(dest_tags)))


def test_add_then_remove_every_sequence() -> None:
    ns = _load_helpers()
    dest_tags = [t for t in _PLUGIN_TAGS if t not in ns["_WRAPPERS"] and t != "root"]
    item = _Item()
    for tag in dest_tags:
        binding = item.add_item_binding()
        binding.insert_action(_Act(tag, vjoy_device_id=2, vjoy_input_id=1), "children")
        leaves = ns["leaves_for_item"](item)
        assert leaves[-1][1] == tag
        assert leaves[-1][0] == len(item.action_sequences) - 1
    assert len(item.action_sequences) == len(dest_tags)
    # Remove from the middle, then the ends, until empty.
    while item.action_sequences:
        mid = len(item.action_sequences) // 2
        item.remove_item_binding(item.action_sequences[mid])
        leaves = ns["leaves_for_item"](item)
        assert [si for si, *_ in leaves] == list(range(len(item.action_sequences)))
    assert ns["leaves_for_item"](item) == []


def test_wrapper_without_child_is_placeholder() -> None:
    ns = _load_helpers()
    item = _Item()
    binding = item.add_item_binding()
    binding.insert_action(_Act("tempo", children=[]), "children")
    leaves = ns["leaves_for_item"](item)
    assert leaves[0][0] == 0
    assert leaves[0][1] == "tempo"
    assert leaves[0][3] == "Add step"


def test_wrapper_with_child_spawns_leaf() -> None:
    ns = _load_helpers()
    item = _Item()
    binding = item.add_item_binding()
    child = _Act("map-to-vjoy", vjoy_device_id=1, vjoy_input_id=4)
    binding.insert_action(_Act("chain", children=[child]), "children")
    leaves = ns["leaves_for_item"](item)
    assert len(leaves) == 1
    assert leaves[0][1] == "map-to-vjoy"
    assert "vJoy 1" in leaves[0][3]


def test_qml_add_and_delete_use_model_slots() -> None:
    qml = _QML.read_text(encoding="utf-8")
    assert "_catalog.addAction(hid, actionName)" in qml
    assert "_catalog.removeSequence(hid, seq)" in qml
    assert "function addActionOnRow" in qml
    assert "function deleteRow" in qml
    add = qml[qml.find("function addActionOnRow") : qml.find("function deleteRow")]
    assert "reloadKeepScroll" not in add
    assert "_catalog.reload()" not in add
    assert "id: _addMenu" in qml
    assert "id: _childMenu" in qml
    assert 'title: "Add"' in qml
    assert 'text: "Delete"' in qml


def test_action_names_lead_matches_plugin_names() -> None:
    src = _BC.read_text(encoding="utf-8")
    # create_instance looks up entry.name. Lead list must use those strings.
    for name in (
        "Map to vJoy",
        "Map to Keyboard",
        "Map to Mouse",
        "Map to Xbox",
        "Macro",
        "Change Mode",
    ):
        assert f'"{name}"' in src, name


def test_add_action_emits_reload_and_refresh() -> None:
    src = _BC.read_text(encoding="utf-8")
    assert "signal.inputItemChanged.connect(self.refreshHid)" in src
    assert "signal.inputItemChanged.connect(self.reload)" not in src
    assert "signal.reloadCurrentInputItem.emit()" in src
    assert "def addAction" in src
    assert "def removeSequence" in src
    assert "def actionNames" in src
    assert "beginInsertRows" in src
    assert "PluginManager().create_instance(name, item.input_type)" in src


def test_inline_editor_can_show_any_sequence() -> None:
    ic = _IC.read_text(encoding="utf-8")
    assert "required property int index" in ic
    assert "required property var modelData" in ic
    assert "sequenceIndex < 0 || index === _root.sequenceIndex" in ic
    header = _HEADER.read_text(encoding="utf-8")
    assert "deleteActionSequnce" in header
    assert "property bool compactMode" in header


def test_wrapper_two_dests_stay_one_row() -> None:
    ns = _load_helpers()
    item = _Item()
    binding = item.add_item_binding()
    a = _Act("map-to-vjoy", vjoy_device_id=1, vjoy_input_id=1)
    b = _Act("map-to-keyboard", keys=["A"])
    binding.insert_action(_Act("tempo", children=[a, b]), "children")
    leaves = ns["leaves_for_item"](item)
    assert len(leaves) == 1
    assert leaves[0][1] == "tempo"
    assert "vJoy 1" in leaves[0][3]

