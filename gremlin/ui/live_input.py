# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import uuid

from PySide6 import QtCore

import dill
import gremlin.ui.type_aliases as ta
from gremlin import event_handler, shared_state
from gremlin.types import InputType

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1


def _norm_guid(value: object) -> str:
    return str(value or "").strip().strip("{}").lower()


@ta.QmlElement
class DeviceLiveState(QtCore.QObject):
    """Live axis/button/hat values for the current physical device tab."""

    guidChanged = QtCore.Signal()
    stampChanged = QtCore.Signal()
    lockedChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._device = None
        self._device_uuid = None
        self._guid = ""
        self._locked = False
        self._kinds: list[str] = []
        self._values: list[float] = []
        self._axis_rows: dict[int, int] = {}
        self._stamp = 0
        self._axis_dirty = False
        self._timer = QtCore.QTimer(self)
        self._timer.setInterval(33)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self._flush_axes)
        event_handler.EventListener().joystick_event.connect(self._on_event)

    def _get_guid(self) -> str:
        return self._guid

    def _get_locked(self) -> bool:
        return self._locked or shared_state.runtime_active()

    def _set_locked(self, value: bool) -> None:
        flag = bool(value)
        if flag == self._locked:
            return
        self._locked = flag
        self.lockedChanged.emit()

    def _clear(self) -> None:
        self._device = None
        self._device_uuid = None
        self._guid = ""
        self._kinds = []
        self._values = []
        self._axis_rows = {}
        self.guidChanged.emit()
        self._bump()

    def _set_guid(self, guid: str) -> None:
        incoming = _norm_guid(guid)
        if not incoming or incoming in ("unknown", str(dill.UUID_Invalid).lower()):
            self._clear()
            return
        if self._guid == incoming and self._device is not None:
            return
        try:
            self._device = dill.DILL.get_device_information_by_guid(
                dill.GUID.from_str(guid)
            )
            self._device_uuid = uuid.UUID(incoming)
            self._guid = incoming
        except Exception:
            self._clear()
            return
        self._kinds = []
        self._values = []
        self._axis_rows = {}
        for i in range(self._device.axis_count):
            self._kinds.append("axis")
            self._values.append(0.0)
            try:
                axis_id = int(self._device.axis_map[i].axis_index)
            except Exception:
                axis_id = i + 1
            self._axis_rows[axis_id] = i
        lookup = getattr(self._device, "axis_lookup", None) or {}
        for axis_id, position in lookup.items():
            try:
                row = int(position) - 1
            except (TypeError, ValueError):
                continue
            if 0 <= row < self._device.axis_count:
                self._axis_rows[int(axis_id)] = row
        for _ in range(self._device.button_count):
            self._kinds.append("button")
            self._values.append(0.0)
        for _ in range(self._device.hat_count):
            self._kinds.append("hat")
            self._values.append(0.0)
        self.guidChanged.emit()
        self._bump()

    def _get_stamp(self) -> int:
        return self._stamp

    def _bump(self) -> None:
        self._stamp += 1
        self.stampChanged.emit()

    def _flush_axes(self) -> None:
        if self._get_locked():
            self._axis_dirty = False
            return
        if self._axis_dirty:
            self._axis_dirty = False
            self._bump()

    def _axis_row(self, identifier: object) -> int | None:
        try:
            key = int(identifier)
        except (TypeError, ValueError):
            return None
        return self._axis_rows.get(key)

    def _axis_value(self, event: event_handler.Event) -> float | None:
        raw = event.value
        if raw is None:
            raw = getattr(event, "raw_value", None)
        if raw is None:
            return None
        try:
            value = float(raw)
        except (TypeError, ValueError):
            return None
        if value > 1.5 or value < -1.5:
            value = max(-1.0, min(1.0, value / 32767.0))
        else:
            value = max(-1.0, min(1.0, value))
        return value

    def _on_event(self, event: event_handler.Event) -> None:
        if self._get_locked():
            return
        if self._device is None or self._device_uuid is None:
            return
        if _norm_guid(event.device_guid) != self._guid:
            return
        if event.event_type == InputType.JoystickAxis:
            row = self._axis_row(event.identifier)
            if row is None:
                return
            value = self._axis_value(event)
            if value is None:
                return
            self._values[row] = value
            self._axis_dirty = True
            if not self._timer.isActive():
                self._timer.start()
            return
        if event.event_type == InputType.JoystickButton:
            row = self._device.axis_count + event.identifier - 1
            if 0 <= row < len(self._values):
                self._values[row] = 1.0 if event.is_pressed else 0.0
                self._bump()
            return
        if event.event_type == InputType.JoystickHat:
            row = (
                self._device.axis_count
                + self._device.button_count
                + event.identifier
                - 1
            )
            if 0 <= row < len(self._values):
                value = event.value
                active = False
                if hasattr(value, "value"):
                    active = value.value != (0, 0)
                self._values[row] = 1.0 if active else 0.0
                self._bump()

    @QtCore.Slot(int, result=str)
    def kindAt(self, index: int) -> str:
        if 0 <= index < len(self._kinds):
            return self._kinds[index]
        return ""

    @QtCore.Slot(int, result=float)
    def valueAt(self, index: int) -> float:
        if 0 <= index < len(self._values):
            return self._values[index]
        return 0.0

    guid = QtCore.Property(str, fget=_get_guid, fset=_set_guid, notify=guidChanged)
    locked = QtCore.Property(bool, fget=_get_locked, fset=_set_locked, notify=lockedChanged)
    stamp = QtCore.Property(int, fget=_get_stamp, notify=stampChanged)


import gremlin.ui.input_pairing  # noqa: F401
