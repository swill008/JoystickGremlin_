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


def dest_event_action(live_while_active: bool, runtime_active: bool, input_locked: bool) -> str:
    if live_while_active and not runtime_active:
        return "drop"
    if not live_while_active and input_locked:
        return "drop"
    return "apply"


def dest_show_live(output_screen: bool, gremlin_active: bool) -> bool:
    if not output_screen:
        return True
    return bool(gremlin_active)


def test_guid_forms_match_vjoy3() -> None:
    u = uuid.UUID("044a6af0-a897-11f1-8000-444553540000")
    forms = [u, str(u), "{" + str(u) + "}", f"GUID({u})"]
    assert {extract_uuid(item) for item in forms} == {str(u).lower()}


def test_vjoy_name_to_id() -> None:
    assert _VJOY_NAME_RE.search("vJoy 3").group(1) == "3"
    assert _VJOY_NAME_RE.search("vJoy 1").group(1) == "1"


def test_vjoy3_active_hid_applies() -> None:
    assert dest_event_action(True, True, True) == "apply"


def test_dest_idle_hid_dropped() -> None:
    assert dest_event_action(True, False, False) == "drop"


def test_dest_paints_when_gremlin_active() -> None:
    assert dest_show_live(True, True) is True
    assert dest_show_live(True, False) is False
    assert dest_show_live(False, True) is True
