# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.config import Configuration
from gremlin.types import PropertyType
from gremlin.ui.device import QML_IMPORT_MAJOR_VERSION, QML_IMPORT_NAME
from vjoy import vjoy

assert QML_IMPORT_NAME == "Gremlin.Device"
assert QML_IMPORT_MAJOR_VERSION == 1

SECTION = "devices"
GROUP = "display"
NAME = "vjoy-tabs"


class _PinHub(QtCore.QObject):
    changed = QtCore.Signal()


HUB = _PinHub()


def _ensure() -> Configuration:
    cfg = Configuration()
    if not cfg.exists(SECTION, GROUP, NAME):
        cfg.register(
            SECTION,
            GROUP,
            NAME,
            PropertyType.List,
            [],
            "vJoy device tabs shown in the main bar.",
            {},
            False,
        )
    return cfg


def _load_pins() -> set[int]:
    pins: set[int] = set()
    raw = _ensure().value(SECTION, GROUP, NAME) or []
    for item in raw:
        try:
            index = int(item)
        except (TypeError, ValueError):
            continue
        if 1 <= index <= 16:
            pins.add(index)
    return pins


def _save_pins(pins: set[int]) -> None:
    _ensure().set(SECTION, GROUP, NAME, sorted(pins))


@ta.QmlElement
class VJoyStatus(QtCore.QObject):
    changed = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._active = [False] * 16
        self._pins = _load_pins()
        HUB.changed.connect(self._reload_pins)

    def _reload_pins(self) -> None:
        self._pins = _load_pins()
        self.changed.emit()

    @QtCore.Slot()
    def refresh(self) -> None:
        active = []
        for index in range(1, 17):
            try:
                active.append(bool(vjoy.device_exists(index)))
            except Exception:
                active.append(False)
        self._active = active
        self._pins = _load_pins()
        self.changed.emit()

    @QtCore.Slot(int, result=bool)
    def isActive(self, index: int) -> bool:
        if 1 <= index <= 16:
            return self._active[index - 1]
        return False

    @QtCore.Slot(int, result=bool)
    def isPinned(self, index: int) -> bool:
        return int(index) in self._pins

    @QtCore.Slot(int, bool)
    def setPinned(self, index: int, pinned: bool) -> None:
        index = int(index)
        if index < 1 or index > 16:
            return
        if pinned:
            self._pins.add(index)
        else:
            self._pins.discard(index)
        _save_pins(self._pins)
        HUB.changed.emit()

    def _count(self) -> int:
        return sum(1 for item in self._active if item)

    def _pin_stamp(self) -> int:
        total = 0
        for index in self._pins:
            total += 1 << index
        return total

    activeCount = QtCore.Property(int, fget=_count, notify=changed)
    pinStamp = QtCore.Property(int, fget=_pin_stamp, notify=changed)
