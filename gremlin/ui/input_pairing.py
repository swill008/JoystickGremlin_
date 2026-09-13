# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import uuid

from PySide6 import QtCore

import dill
from gremlin import device_initialization, event_handler, shared_state
from gremlin.types import InputType
from gremlin.ui import xbox_maps
import gremlin.ui.type_aliases as ta
from vigem.xbox import XboxTarget

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
        return uuid.UUID(str(value or "").strip().strip("{}"))
    except Exception:
        return None


def _walk_actions(action) -> list:
    found = [action]
    getter = getattr(action, "get_actions", None)
    if not callable(getter):
        return found
    try:
        buckets = getter()
    except Exception:
        return found
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


def _xbox_maps_for_item(item) -> list[tuple[int, str]]:
    return xbox_maps.xbox_maps_for_item(item)


def _has_pair_maps(item) -> bool:
    return bool(_maps_for_item(item) or _xbox_maps_for_item(item))


def _xbox_label(target: str) -> str:
    try:
        return XboxTarget.from_string(target).label
    except Exception:
        return str(target or "Xbox")


def _pair_label_for_items(items) -> str:
    vjoy_ids = sorted({vid for item in items or [] for vid, _, _ in _maps_for_item(item)})
    xbox_ids = sorted({pad for item in items or [] for pad, _ in _xbox_maps_for_item(item)})
    parts = [f"vJoy Device {vid}" for vid in vjoy_ids]
    parts.extend(f"Xbox 360 {pad}" for pad in xbox_ids)
    return ", ".join(parts)


def _items_for_guid(guid: str):
    profile = shared_state.current_profile
    if profile is None:
        return []
    uid = _guid(guid)
    if uid is None:
        return []
    return profile.inputs.get(uid, []) or []


def _vjoy_guid(vjoy_id: int) -> str:
    try:
        for device in device_initialization.vjoy_devices():
            if int(getattr(device, "vjoy_id", -1)) == int(vjoy_id):
                return str(device.device_guid)
    except Exception:
        return ""
    return ""


def _device_name(guid: str) -> str:
    uid = _guid(guid)
    hardware = str(guid)
    try:
        if uid is not None:
            hardware = dill.DILL.get_device_name(dill.GUID.from_uuid(uid)) or hardware
    except Exception:
        pass
    return hardware


def _source_label(input_type: InputType, identifier: int) -> str:
    if input_type == InputType.JoystickAxis:
        return AXIS_LABELS.get(identifier, f"A{identifier}")
    if input_type == InputType.JoystickHat:
        return f"H{identifier}"
    return str(identifier)


def _blank_dest() -> dict:
    return {
        "destKind": "",
        "vjoyId": 0,
        "vjoyInput": 0,
        "vjoyLabel": "",
        "vjoyGuid": "",
        "xboxPad": 0,
        "xboxTarget": "",
        "xboxLabel": "",
    }


def _mapped_rows(guid: str, input_type: InputType) -> list[dict]:
    rows: list[dict] = []
    seen: set[tuple] = set()
    for item in _items_for_guid(guid):
        if getattr(item, "input_type", None) != input_type:
            continue
        try:
            identifier = int(item.input_id)
        except Exception:
            continue
        src = _source_label(input_type, identifier)
        for vjoy_id, vtype, vinput in _maps_for_item(item):
            key = ("vjoy", identifier, vjoy_id, vinput)
            if key in seen:
                continue
            seen.add(key)
            if vtype == InputType.JoystickAxis:
                dest = AXIS_LABELS.get(int(vinput), f"A{vinput}")
            elif vtype == InputType.JoystickHat:
                dest = f"H{vinput}"
            else:
                dest = f"B{vinput}"
            row = _blank_dest()
            row.update(
                {
                    "identifier": identifier,
                    "label": src,
                    "destKind": "vjoy",
                    "vjoyId": int(vjoy_id),
                    "vjoyInput": int(vinput),
                    "vjoyLabel": f"vJoy {vjoy_id} {dest}",
                    "vjoyGuid": _vjoy_guid(vjoy_id),
                }
            )
            rows.append(row)
        for pad, target in _xbox_maps_for_item(item):
            key = ("xbox", identifier, pad, target)
            if key in seen:
                continue
            seen.add(key)
            row = _blank_dest()
            row.update(
                {
                    "identifier": identifier,
                    "label": src,
                    "destKind": "xbox",
                    "xboxPad": int(pad),
                    "xboxTarget": str(target),
                    "xboxLabel": f"Xbox {pad} {_xbox_label(target)}",
                }
            )
            rows.append(row)
    rows.sort(
        key=lambda row: (
            row["identifier"],
            row["destKind"],
            row["vjoyId"],
            row["vjoyInput"],
            row["xboxPad"],
            row["xboxTarget"],
        )
    )
    return rows


def _xbox_pads_for_guid(guid: str) -> list[int]:
    pads = {
        pad
        for item in _items_for_guid(guid)
        for pad, _ in _xbox_maps_for_item(item)
    }
    return sorted(pads)


class _MappedModel(QtCore.QAbstractListModel):
    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"identifier"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"label"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"vjoyId"),
        QtCore.Qt.ItemDataRole.UserRole + 4: QtCore.QByteArray(b"vjoyInput"),
        QtCore.Qt.ItemDataRole.UserRole + 5: QtCore.QByteArray(b"vjoyLabel"),
        QtCore.Qt.ItemDataRole.UserRole + 6: QtCore.QByteArray(b"vjoyGuid"),
        QtCore.Qt.ItemDataRole.UserRole + 7: QtCore.QByteArray(b"destKind"),
        QtCore.Qt.ItemDataRole.UserRole + 8: QtCore.QByteArray(b"xboxPad"),
        QtCore.Qt.ItemDataRole.UserRole + 9: QtCore.QByteArray(b"xboxTarget"),
        QtCore.Qt.ItemDataRole.UserRole + 10: QtCore.QByteArray(b"xboxLabel"),
    }

    guidChanged = QtCore.Signal()

    def __init__(self, input_type: InputType, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._input_type = input_type
        self._guid = ""
        self._rows: list[dict] = []

    def _reload(self) -> None:
        self.beginResetModel()
        self._rows = _mapped_rows(self._guid, self._input_type) if self._guid else []
        self.endResetModel()

    def _get_guid(self) -> str:
        return self._guid

    def _set_guid(self, guid: str) -> None:
        text = str(guid or "")
        if text == self._guid:
            return
        self._guid = text
        self._reload()
        self.guidChanged.emit()

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._rows)

    def data(self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._rows)):
            return None
        row = self._rows[index.row()]
        key = bytes(self.roles.get(role, b"")).decode()
        return row.get(key)

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles

    guid = QtCore.Property(str, fget=_get_guid, fset=_set_guid, notify=guidChanged)


@ta.QmlElement
class MappedAxisModel(_MappedModel):
    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(InputType.JoystickAxis, parent)


@ta.QmlElement
class MappedButtonModel(_MappedModel):
    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(InputType.JoystickButton, parent)


@ta.QmlElement
class MappedHatModel(_MappedModel):
    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(InputType.JoystickHat, parent)


@ta.QmlElement
class MappedXboxPadModel(QtCore.QAbstractListModel):
    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"padId"),
    }
    guidChanged = QtCore.Signal()
    countChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._guid = ""
        self._rows: list[dict] = []

    def _reload(self) -> None:
        self.beginResetModel()
        self._rows = [{"padId": pad} for pad in _xbox_pads_for_guid(self._guid)]
        self.endResetModel()
        self.countChanged.emit()

    def _get_guid(self) -> str:
        return self._guid

    def _set_guid(self, guid: str) -> None:
        text = str(guid or "")
        if text == self._guid:
            return
        self._guid = text
        self._reload()
        self.guidChanged.emit()

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._rows)

    def data(self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._rows)):
            return None
        row = self._rows[index.row()]
        key = bytes(self.roles.get(role, b"")).decode()
        return row.get(key)

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles

    guid = QtCore.Property(str, fget=_get_guid, fset=_set_guid, notify=guidChanged)

    def _get_count(self) -> int:
        return len(self._rows)

    count = QtCore.Property(int, fget=_get_count, notify=countChanged)


@ta.QmlElement
class PairDeviceModel(QtCore.QAbstractListModel):
    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"guid"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"name"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"pairLabel"),
    }

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._rows: list[dict] = []
        self.reload()

    @QtCore.Slot()
    def reload(self) -> None:
        self.beginResetModel()
        self._rows = []
        profile = shared_state.current_profile
        if profile is not None:
            for device_id, items in (profile.inputs or {}).items():
                if not any(_has_pair_maps(item) for item in items or []):
                    continue
                guid = str(device_id)
                self._rows.append(
                    {
                        "guid": guid,
                        "name": _device_name(guid),
                        "pairLabel": _pair_label_for_items(items),
                    }
                )
        self._rows.sort(key=lambda row: row["name"].lower())
        self.endResetModel()

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._rows)

    def data(self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._rows)):
            return None
        row = self._rows[index.row()]
        key = bytes(self.roles.get(role, b"")).decode()
        return row.get(key)

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles


@ta.QmlElement
class PairLiveState(QtCore.QObject):
    stampChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._guid = ""
        self._uid = None
        self._hw_axis: dict[int, float] = {}
        self._hw_button: dict[int, float] = {}
        self._vj_axis: dict[tuple[str, int], float] = {}
        self._vj_button: dict[tuple[str, int], float] = {}
        self._stamp = 0
        event_handler.EventListener().joystick_event.connect(self._on_event)

    def _bump(self) -> None:
        self._stamp += 1
        self.stampChanged.emit()

    def _get_guid(self) -> str:
        return self._guid

    def _set_guid(self, guid: str) -> None:
        self._guid = str(guid or "")
        self._uid = _guid(self._guid)
        self._hw_axis.clear()
        self._hw_button.clear()
        self._bump()

    def _norm(self, value: object) -> str:
        return str(value or "").strip().strip("{}").lower()

    def _on_event(self, event: event_handler.Event) -> None:
        ev = self._norm(event.device_guid)
        if self._uid is not None and ev == self._norm(self._uid):
            if event.event_type == InputType.JoystickAxis:
                try:
                    self._hw_axis[int(event.identifier)] = float(event.value)
                    self._bump()
                except Exception:
                    return
            elif event.event_type == InputType.JoystickButton:
                try:
                    self._hw_button[int(event.identifier)] = 1.0 if event.is_pressed else 0.0
                    self._bump()
                except Exception:
                    return
            return
        if event.event_type == InputType.JoystickAxis:
            try:
                self._vj_axis[(ev, int(event.identifier))] = float(event.value)
                self._bump()
            except Exception:
                return
        elif event.event_type == InputType.JoystickButton:
            try:
                self._vj_button[(ev, int(event.identifier))] = (
                    1.0 if event.is_pressed else 0.0
                )
                self._bump()
            except Exception:
                return

    @QtCore.Slot(int, result=float)
    def axisValue(self, identifier: int) -> float:
        return float(self._hw_axis.get(int(identifier), 0.0))

    @QtCore.Slot(int, result=float)
    def buttonValue(self, identifier: int) -> float:
        return float(self._hw_button.get(int(identifier), 0.0))

    @QtCore.Slot(str, int, result=float)
    def vjoyAxisValue(self, vjoy_guid: str, identifier: int) -> float:
        return float(self._vj_axis.get((self._norm(vjoy_guid), int(identifier)), 0.0))

    @QtCore.Slot(str, int, result=float)
    def vjoyButtonValue(self, vjoy_guid: str, identifier: int) -> float:
        return float(self._vj_button.get((self._norm(vjoy_guid), int(identifier)), 0.0))

    def _get_stamp(self) -> int:
        return self._stamp

    guid = QtCore.Property(str, fget=_get_guid, fset=_set_guid)
    stamp = QtCore.Property(int, fget=_get_stamp, notify=stampChanged)


@ta.QmlElement
class InputPairing(QtCore.QObject):
    changed = QtCore.Signal()

    @QtCore.Slot(int, result=str)
    def axisLabel(self, identifier: int) -> str:
        return AXIS_LABELS.get(int(identifier), f"A{identifier}")

    @QtCore.Slot(str, result=str)
    def pairedDeviceLabel(self, guid: str) -> str:
        return _pair_label_for_items(_items_for_guid(guid))
