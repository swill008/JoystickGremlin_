# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import uuid

from PySide6 import QtCore

from gremlin import shared_state
from gremlin.types import InputType
import gremlin.ui.type_aliases as ta

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1

AXIS_LABELS = {
    1: "X",
    2: "Y",
    3: "Z",
    4: "Rx",
    5: "Ry",
    6: "Rz",
    7: "S1",
    8: "S2",
}


def _guid(value: object) -> uuid.UUID | None:
    try:
        return uuid.UUID(str(value).strip().strip("{}"))
    except Exception:
        return None


def _walk_actions(action) -> list:
    found = [action]
    getter = getattr(action, "get_actions", None)
    if callable(getter):
        try:
            buckets = getter()
        except Exception:
            buckets = []
        if isinstance(buckets, (list, tuple)):
            for bucket in buckets:
                if isinstance(bucket, (list, tuple)):
                    for child in bucket:
                        found.extend(_walk_actions(child))
    return found


def _maps_for_item(item) -> list[tuple[int, object, int]]:
    out: list[tuple[int, object, int]] = []
    if item is None:
        return out
    for seq in getattr(item, "action_sequences", []) or []:
        root = getattr(seq, "root_action", None)
        if root is None:
            continue
        for action in _walk_actions(root):
            if getattr(action, "tag", "") != "map-to-vjoy":
                continue
            try:
                out.append(
                    (
                        int(action.vjoy_device_id),
                        getattr(action, "vjoy_input_type", None),
                        int(action.vjoy_input_id),
                    )
                )
            except Exception:
                continue
    return out


def _items_for_guid(guid: str):
    profile = shared_state.current_profile
    if profile is None:
        return []
    uid = _guid(guid)
    if uid is None:
        return []
    return profile.inputs.get(uid, []) or []


@ta.QmlElement
class InputPairing(QtCore.QObject):
    changed = QtCore.Signal()

    @QtCore.Slot(int, result=str)
    def axisLabel(self, identifier: int) -> str:
        return AXIS_LABELS.get(int(identifier), f"A{identifier}")

    @QtCore.Slot(str, result=str)
    def pairedDeviceLabel(self, guid: str) -> str:
        ids = sorted({vid for item in _items_for_guid(guid) for vid, _, _ in _maps_for_item(item)})
        if not ids:
            return ""
        return ", ".join(f"vJoy Device {vid}" for vid in ids)

    @QtCore.Slot(str, int, result=str)
    def pairedAxisLabel(self, guid: str, identifier: int) -> str:
        return self._label_for(guid, InputType.JoystickAxis, identifier, "A")

    @QtCore.Slot(str, int, result=str)
    def pairedButtonLabel(self, guid: str, identifier: int) -> str:
        return self._label_for(guid, InputType.JoystickButton, identifier, "B")

    def _label_for(self, guid: str, input_type: InputType, identifier: int, prefix: str) -> str:
        for item in _items_for_guid(guid):
            if getattr(item, "input_type", None) != input_type:
                continue
            if int(getattr(item, "input_id", -1)) != int(identifier):
                continue
            maps = _maps_for_item(item)
            if not maps:
                return ""
            vid, vtype, vid_in = maps[0]
            kind = prefix
            if vtype == InputType.JoystickAxis:
                kind = AXIS_LABELS.get(int(vid_in), f"A{vid_in}")
                return f"vJoy {vid}  {kind}"
            if vtype == InputType.JoystickButton:
                kind = f"B{vid_in}"
            elif vtype == InputType.JoystickHat:
                kind = f"H{vid_in}"
            return f"vJoy {vid}  {kind}"
        return ""
