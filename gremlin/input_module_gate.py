# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only
"""Claim gate for the runtime wire: HID only if an input module passed it."""

from __future__ import annotations

_BUCKET = {
    "axis": "axes",
    "button": "buttons",
    "hat": "hats",
}


def norm_guid(value: object) -> str:
    if value is not None and hasattr(value, "uuid"):
        value = value.uuid
    return str(value or "").strip().strip("{}").replace("-", "").lower()


def event_kind(event_type: object) -> str:
    name = str(getattr(event_type, "name", event_type) or "")
    text = name.lower()
    if "axis" in text:
        return "axis"
    if "hat" in text:
        return "hat"
    if "button" in text:
        return "button"
    return ""


def claim_allows(claim: dict | None, kind: str, hid: int) -> bool:
    if not claim or not kind:
        return False
    bucket = _BUCKET.get(kind)
    if not bucket:
        return False
    try:
        want = int(hid)
    except (TypeError, ValueError):
        return False
    return want in {int(x) for x in (claim.get(bucket) or [])}


def should_forward(
    guid: object,
    event_type: object,
    hid: object,
    *,
    claims: dict[str, dict],
    dest_guids: set[str],
    passthrough: set[str],
) -> bool:
    """True if this HID event may enter the wire (Map to vJoy, etc.)."""
    key = norm_guid(guid)
    if not key:
        return False
    if key in passthrough:
        return True
    if key in dest_guids:
        return False
    try:
        ident = int(hid)
    except (TypeError, ValueError):
        return False
    return claim_allows(claims.get(key), event_kind(event_type), ident)
