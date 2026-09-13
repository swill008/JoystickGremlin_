# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

import dill
from gremlin import device_initialization, event_handler, shared_state
from gremlin.signal import signal
import gremlin.ui.type_aliases as ta
from gremlin.ui import input_pairing as pairing

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1

OSC_GUID = "a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70"


def _norm(value: object) -> str:
    if value is not None and hasattr(value, "uuid"):
        value = value.uuid
    return str(value or "").strip().strip("{}").lower()


def _is_vjoy_name(name: str) -> bool:
    return str(name or "").lower().startswith("vjoy")


def _connected_keys() -> set[str]:
    keys: set[str] = set()
    for getter in (
        device_initialization.joystick_devices,
        device_initialization.physical_devices,
        device_initialization.input_devices,
    ):
        try:
            devices = getter()
        except Exception:
            continue
        for device in devices or []:
            key = _norm(getattr(device, "device_guid", ""))
            if key:
                keys.add(key)
    for guid in (
        dill.UUID_Keyboard,
        dill.UUID_LogicalDevice,
        OSC_GUID,
    ):
        keys.add(_norm(guid))
    return keys


@ta.QmlElement
class ViewerDeviceModel(QtCore.QAbstractListModel):
    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"guid"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"name"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"pairLabel"),
        QtCore.Qt.ItemDataRole.UserRole + 4: QtCore.QByteArray(b"mapped"),
    }

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._rows: list[dict] = []
        self.reload()
        signal.profileChanged.connect(self.reload)
        event_handler.EventListener().device_change_event.connect(self.reload)

    @QtCore.Slot()
    def reload(self) -> None:
        self.beginResetModel()
        self._rows = []
        seen: set[str] = set()
        connected = _connected_keys()
        profile = shared_state.current_profile
        if profile is not None:
            for device_id, items in (profile.inputs or {}).items():
                if not any(pairing._has_pair_maps(item) for item in items or []):
                    continue
                guid = str(device_id)
                key = _norm(guid)
                if key not in connected:
                    continue
                self._rows.append(
                    {
                        "guid": guid,
                        "name": pairing._device_name(guid),
                        "pairLabel": pairing._pair_label_for_items(items),
                        "mapped": True,
                    }
                )
                seen.add(key)
        try:
            devices = device_initialization.physical_devices()
        except Exception:
            devices = []
        for device in devices:
            guid = str(getattr(device, "device_guid", ""))
            name = str(getattr(device, "name", guid))
            if _is_vjoy_name(name):
                continue
            key = _norm(guid)
            if not key or key not in connected or key in seen:
                continue
            self._rows.append(
                {
                    "guid": guid,
                    "name": pairing._device_name(guid) if guid else name,
                    "pairLabel": "",
                    "mapped": False,
                }
            )
            seen.add(key)
        extras = [
            (str(dill.UUID_Keyboard), "Keyboard"),
            (str(dill.UUID_LogicalDevice), "Logical Device"),
            (OSC_GUID, "OSC"),
        ]
        for guid, label in extras:
            key = _norm(guid)
            if key in seen:
                continue
            self._rows.append(
                {
                    "guid": guid,
                    "name": label,
                    "pairLabel": "",
                    "mapped": False,
                }
            )
            seen.add(key)
        self._rows.sort(key=lambda row: (not row["mapped"], str(row["name"]).lower()))
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
