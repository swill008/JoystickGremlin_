# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

from gremlin import event_handler
from gremlin.types import InputType
import gremlin.ui.type_aliases as ta
from gremlin.ui import input_pairing as pairing
from vigem.xbox import XboxProxy

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1


def _norm(value: object) -> str:
    if value is not None and hasattr(value, "uuid"):
        value = value.uuid
    return str(value or "").strip().strip("{}").lower()


@ta.QmlElement
class PairLiveThrottle(QtCore.QObject):
    stampChanged = QtCore.Signal()
    axisStampChanged = QtCore.Signal()
    buttonStampChanged = QtCore.Signal()
    xboxStampChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._guid = ""
        self._uid = None
        self._hw_axis: dict[int, float] = {}
        self._hw_button: dict[int, float] = {}
        self._vj_axis: dict[tuple[str, int], float] = {}
        self._vj_button: dict[tuple[str, int], float] = {}
        self._xbox: dict[int, dict[str, float]] = {}
        self._xbox_pads: set[int] = set()
        self._stamp = 0
        self._axis_stamp = 0
        self._button_stamp = 0
        self._xbox_stamp = 0
        self._watch = set()
        self._axis_dirty = False
        self._timer = QtCore.QTimer(self)
        self._timer.setInterval(50)
        self._timer.setSingleShot(True)
        self._timer.timeout.connect(self._flush)
        self._xbox_timer = QtCore.QTimer(self)
        self._xbox_timer.setInterval(50)
        self._xbox_timer.timeout.connect(self._poll_xbox)
        event_handler.EventListener().joystick_event.connect(self._on_event)

    def _bump(self) -> None:
        self._stamp += 1
        self.stampChanged.emit()

    def _bump_axis(self) -> None:
        self._axis_stamp += 1
        self.axisStampChanged.emit()

    def _bump_button(self) -> None:
        self._button_stamp += 1
        self.buttonStampChanged.emit()

    def _flush(self) -> None:
        if self._axis_dirty:
            self._axis_dirty = False
            self._bump_axis()

    def _get_guid(self) -> str:
        return self._guid

    def _set_guid(self, guid: str) -> None:
        self._guid = str(guid or "")
        self._uid = pairing._guid(self._guid)
        self._hw_axis.clear()
        self._hw_button.clear()
        self._xbox.clear()
        self._watch = {_norm(self._guid)} if self._guid else set()
        self._xbox_pads = set()
        for kind in (
            InputType.JoystickAxis,
            InputType.JoystickButton,
            InputType.JoystickHat,
        ):
            for row in pairing._mapped_rows(self._guid, kind):
                vg = _norm(row.get("vjoyGuid", ""))
                if vg:
                    self._watch.add(vg)
                pad = int(row.get("xboxPad") or 0)
                if pad:
                    self._xbox_pads.add(pad)
        if self._xbox_pads:
            if not self._xbox_timer.isActive():
                self._xbox_timer.start()
        else:
            self._xbox_timer.stop()
        self._bump()
        self._poll_xbox()

    def _on_event(self, event: event_handler.Event) -> None:
        ev = _norm(event.device_guid)
        if ev not in self._watch:
            return
        is_hw = self._uid is not None and ev == _norm(self._uid)
        if event.event_type == InputType.JoystickAxis:
            try:
                value = float(event.value)
                ident = int(event.identifier)
            except Exception:
                return
            if is_hw:
                self._hw_axis[ident] = value
            else:
                self._vj_axis[(ev, ident)] = value
            self._axis_dirty = True
            if not self._timer.isActive():
                self._timer.start()
            return
        if event.event_type == InputType.JoystickButton:
            try:
                ident = int(event.identifier)
                pressed = 1.0 if event.is_pressed else 0.0
            except Exception:
                return
            if is_hw:
                self._hw_button[ident] = pressed
            else:
                self._vj_button[(ev, ident)] = pressed
            self._bump_button()

    @QtCore.Slot(int, result=float)
    def axisValue(self, identifier: int) -> float:
        return float(self._hw_axis.get(int(identifier), 0.0))

    @QtCore.Slot(int, result=float)
    def buttonValue(self, identifier: int) -> float:
        return float(self._hw_button.get(int(identifier), 0.0))

    @QtCore.Slot(str, int, result=float)
    def vjoyAxisValue(self, vjoy_guid: str, identifier: int) -> float:
        return float(self._vj_axis.get((_norm(vjoy_guid), int(identifier)), 0.0))

    @QtCore.Slot(str, int, result=float)
    def vjoyButtonValue(self, vjoy_guid: str, identifier: int) -> float:
        return float(self._vj_button.get((_norm(vjoy_guid), int(identifier)), 0.0))

    def _poll_xbox(self) -> None:
        changed = False
        proxy = XboxProxy()
        for pad_id in self._xbox_pads:
            snap = proxy.snapshot(pad_id) or {}
            if self._xbox.get(pad_id) != snap:
                self._xbox[pad_id] = snap
                changed = True
        if changed:
            self._xbox_stamp += 1
            self.xboxStampChanged.emit()
            self._bump_axis()
            self._bump_button()

    @QtCore.Slot(int, str, result=float)
    def xboxValue(self, pad_id: int, target: str) -> float:
        key = str(target or "").strip().lower().replace("-", "_")
        return float(self._xbox.get(int(pad_id), {}).get(key, 0.0))

    def _get_stamp(self) -> int:
        return self._stamp

    def _get_axis_stamp(self) -> int:
        return self._axis_stamp

    def _get_button_stamp(self) -> int:
        return self._button_stamp

    guid = QtCore.Property(str, fget=_get_guid, fset=_set_guid)
    stamp = QtCore.Property(int, fget=_get_stamp, notify=stampChanged)
    axisStamp = QtCore.Property(int, fget=_get_axis_stamp, notify=axisStampChanged)
    buttonStamp = QtCore.Property(int, fget=_get_button_stamp, notify=buttonStampChanged)

    def _get_xbox_stamp(self) -> int:
        return self._xbox_stamp

    xboxStamp = QtCore.Property(int, fget=_get_xbox_stamp, notify=xboxStampChanged)
