# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import uuid

from PySide6 import QtCore

import dill
import gremlin.ui.type_aliases as ta
from gremlin import event_handler
from gremlin.types import InputType

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1


@ta.QmlElement
class DeviceLiveState(QtCore.QObject):
    """Live axis/button/hat values for the current physical device tab."""

    guidChanged = QtCore.Signal()
    stampChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._device = None
        self._device_uuid = None
        self._kinds: list[str] = []
        self._values: list[float] = []
        self._stamp = 0
        self._axis_dirty = False
        self._timer = QtCore.QTimer(self)
        self._timer.setInterval(33)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self._flush_axes)
        event_handler.EventListener().joystick_event.connect(self._on_event)

    def _get_guid(self) -> str:
        return str(self._device.device_guid) if self._device is not None else ""

    def _set_guid(self, guid: str) -> None:
        if not guid or guid == "Unknown":
            self._device = None
            self._device_uuid = None
            self._kinds = []
            self._values = []
            self.guidChanged.emit()
            self._bump()
            return
        if self._device is not None and guid == str(self._device.device_guid):
            return
        try:
            self._device = dill.DILL.get_device_information_by_guid(
                dill.GUID.from_str(guid)
            )
            self._device_uuid = uuid.UUID(guid)
        except Exception:
            self._device = None
            self._device_uuid = None
            self._kinds = []
            self._values = []
            self.guidChanged.emit()
            self._bump()
            return
        self._kinds = []
        self._values = []
        for i in range(self._device.axis_count):
            self._kinds.append("axis")
            self._values.append(0.0)
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
        if self._axis_dirty:
            self._axis_dirty = False
            self._bump()

    def _on_event(self, event: event_handler.Event) -> None:
        if self._device is None or self._device_uuid is None:
            return
        if event.device_guid != self._device_uuid:
            return
        if event.event_type == InputType.JoystickAxis:
            for i in range(self._device.axis_count):
                if self._device.axis_map[i].axis_index == event.identifier:
                    try:
                        self._values[i] = float(event.value)
                    except (TypeError, ValueError):
                        return
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
    stamp = QtCore.Property(int, fget=_get_stamp, notify=stampChanged)
