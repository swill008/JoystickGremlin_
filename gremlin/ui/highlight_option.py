# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

from gremlin.config import Configuration
from gremlin.types import PropertyType
import gremlin.ui.type_aliases as ta

QML_IMPORT_NAME = "Gremlin.Config"
QML_IMPORT_MAJOR_VERSION = 1

SECTION = "global"
GROUP = "general"
NAME = "input-highlight-speed"
SPEEDS = ("Slow", "Medium", "Fast")
DEFAULT = "Slow"

_THRESHOLDS = {
    "Slow": 0.33,
    "Medium": 0.15,
    "Fast": 0.06,
}


def normalize_speed(value: object) -> str:
    text = str(value or DEFAULT).strip().title()
    if text not in SPEEDS:
        return DEFAULT
    return text


def highlight_threshold(value: object | None = None) -> float:
    if value is None:
        cfg = Configuration()
        if cfg.exists(SECTION, GROUP, NAME):
            value = cfg.value(SECTION, GROUP, NAME)
    return _THRESHOLDS[normalize_speed(value)]


def accept_first_axis(value: object | None = None) -> bool:
    if value is None:
        cfg = Configuration()
        if cfg.exists(SECTION, GROUP, NAME):
            value = cfg.value(SECTION, GROUP, NAME)
    return normalize_speed(value) != "Slow"


def ensure_registered() -> None:
    cfg = Configuration()
    if not cfg.exists(SECTION, GROUP, NAME):
        cfg.register(
            SECTION,
            GROUP,
            NAME,
            PropertyType.String,
            DEFAULT,
            "How quickly the UI jumps to an input that was used.",
            {},
            False,
        )


@ta.QmlElement
class HighlightSpeedModel(QtCore.QObject):
    speedChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        ensure_registered()
        self._config = Configuration()

    def _get_speed(self) -> str:
        if self._config.exists(SECTION, GROUP, NAME):
            return normalize_speed(self._config.value(SECTION, GROUP, NAME))
        return DEFAULT

    def _set_speed(self, value: str) -> None:
        ensure_registered()
        speed = normalize_speed(value)
        current = self._get_speed()
        if speed != current:
            self._config.set(SECTION, GROUP, NAME, speed)
        self.speedChanged.emit()

    @QtCore.Slot(str)
    def setSpeed(self, value: str) -> None:
        self._set_speed(value)

    speed = QtCore.Property(str, fget=_get_speed, fset=_set_speed, notify=speedChanged)
