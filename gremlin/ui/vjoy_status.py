# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.ui.device import QML_IMPORT_MAJOR_VERSION, QML_IMPORT_NAME
from vjoy import vjoy

assert QML_IMPORT_NAME == "Gremlin.Device"
assert QML_IMPORT_MAJOR_VERSION == 1


@ta.QmlElement
class VJoyStatus(QtCore.QObject):
    changed = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._active = [False] * 16

    @QtCore.Slot()
    def refresh(self) -> None:
        active = []
        for index in range(1, 17):
            try:
                active.append(bool(vjoy.device_exists(index)))
            except Exception:
                active.append(False)
        self._active = active
        self.changed.emit()

    @QtCore.Slot(int, result=bool)
    def isActive(self, index: int) -> bool:
        if 1 <= index <= 16:
            return self._active[index - 1]
        return False

    def _count(self) -> int:
        return sum(1 for item in self._active if item)

    activeCount = QtCore.Property(int, fget=_count, notify=changed)
