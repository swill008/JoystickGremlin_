# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

import re
import uuid

_UUID_RE = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
    re.I,
)
_VJOY_NAME_RE = re.compile(r"vjoy\s*(\d+)", re.I)


def extract_uuid(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, uuid.UUID):
        return str(value).lower()
    nested = getattr(value, "uuid", None)
    if isinstance(nested, uuid.UUID):
        return str(nested).lower()
    text = str(value or "")
    hit = _UUID_RE.search(text)
    if hit:
        return hit.group(0).lower()
    return text.strip().strip("{}").lower()


def dest_hid_action(live_while_active: bool, input_locked: bool) -> str:
    if live_while_active:
        return "drop"
    if input_locked:
        return "drop"
    return "apply"


def dest_show_live(output_screen: bool, runtime_active: bool, driven: bool) -> bool:
    if not output_screen:
        return True
    return bool(runtime_active and driven)


def dest_driven(running: bool, feeder_present: bool) -> bool:
    return bool(running and feeder_present)


def test_guid_forms_match_vjoy3() -> None:
    u = uuid.UUID("044a6af0-a897-11f1-8000-444553540000")
    forms = [u, str(u), "{" + str(u) + "}", f"GUID({u})"]
    assert {extract_uuid(item) for item in forms} == {str(u).lower()}


def test_vjoy_name_to_id() -> None:
    assert _VJOY_NAME_RE.search("vJoy 3").group(1) == "3"
    assert _VJOY_NAME_RE.search("vJoy 1").group(1) == "1"


def test_dest_config_never_uses_hid() -> None:
    assert dest_hid_action(True, False) == "drop"
    assert dest_hid_action(True, True) == "drop"


def test_input_config_hid_when_not_locked() -> None:
    assert dest_hid_action(False, False) == "apply"
    assert dest_hid_action(False, True) == "drop"


def test_dest_paints_only_when_active_and_feeder_present() -> None:
    assert dest_show_live(True, True, True) is True
    assert dest_show_live(True, True, False) is False
    assert dest_show_live(True, False, True) is False
    assert dest_show_live(False, True, False) is True


def test_feeder_driven() -> None:
    assert dest_driven(True, True) is True
    assert dest_driven(True, False) is False
    assert dest_driven(False, True) is False


import ast
from pathlib import Path

_REPO = Path(__file__).resolve().parents[2]


def _hat_xy(direction: object) -> tuple[int, int]:
    if direction is None:
        return (0, 0)
    raw = getattr(direction, "value", direction)
    if isinstance(raw, (tuple, list)) and len(raw) >= 2:
        try:
            return (int(raw[0]), int(raw[1]))
        except (TypeError, ValueError):
            return (0, 0)
    return (0, 0)


def test_hat_xy_center_and_east() -> None:
    assert _hat_xy(None) == (0, 0)
    assert _hat_xy((1, 0)) == (1, 0)
    assert _hat_xy((0, 1)) == (0, 1)
    assert _hat_xy((-1, -1)) == (-1, -1)

    class Enumish:
        value = (1, 1)

    assert _hat_xy(Enumish()) == (1, 1)


def test_qml_element_on_device_live_state_class() -> None:
    tree = ast.parse((_REPO / "gremlin/ui/live_input.py").read_text(encoding="utf-8"))
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == "DeviceLiveState")

    def deco_names(node) -> list[str]:
        names = []
        for d in node.decorator_list:
            if isinstance(d, ast.Attribute):
                names.append(d.attr)
            elif isinstance(d, ast.Name):
                names.append(d.id)
        return names

    assert "QmlElement" in deco_names(cls)
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == "_hat_xy":
            assert "QmlElement" not in deco_names(node)


def test_output_module_view_binds_hat_xy() -> None:
    text = (_REPO / "qml/OutputModuleView.qml").read_text(encoding="utf-8")
    assert "hatXAt" in text
    assert "hatYAt" in text
    assert "liveVal(idx) > 0.5 ? Qt.point(0, 1)" not in text
    assert "property var axisPick:" not in text
