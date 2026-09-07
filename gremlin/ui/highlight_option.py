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
SCOPE_NAME = "input-highlight-scope"
SPEEDS = ("Slow", "Medium", "Fast")
SCOPES = ("This tab", "Any device")
DEFAULT = "Slow"
DEFAULT_SCOPE = "This tab"


def normalize_speed(value: object) -> str:
    text = str(value or DEFAULT).strip().title()
    if text not in SPEEDS:
        return DEFAULT
    return text


def normalize_scope(value: object) -> str:
    text = str(value or DEFAULT_SCOPE).strip()
    lowered = text.lower()
    if lowered in ("any device", "any", "follow", "switch"):
        return "Any device"
    if lowered in ("this tab", "this", "match", "active tab"):
        return "This tab"
    if text in SCOPES:
        return text
    return DEFAULT_SCOPE


def highlight_follows_any_device(value: object | None = None) -> bool:
    if value is None:
        cfg = Configuration()
        if cfg.exists(SECTION, GROUP, SCOPE_NAME):
            value = cfg.value(SECTION, GROUP, SCOPE_NAME)
    return normalize_scope(value) == "Any device"


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
    if not cfg.exists(SECTION, GROUP, SCOPE_NAME):
        cfg.register(
            SECTION,
            GROUP,
            SCOPE_NAME,
            PropertyType.String,
            DEFAULT_SCOPE,
            "Whether highlighting stays on the active device tab or follows any device.",
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


@ta.QmlElement
class HighlightScopeModel(QtCore.QObject):
    scopeChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        ensure_registered()
        self._config = Configuration()

    def _get_scope(self) -> str:
        if self._config.exists(SECTION, GROUP, SCOPE_NAME):
            return normalize_scope(self._config.value(SECTION, GROUP, SCOPE_NAME))
        return DEFAULT_SCOPE

    def _set_scope(self, value: str) -> None:
        ensure_registered()
        scope = normalize_scope(value)
        current = self._get_scope()
        if scope != current:
            self._config.set(SECTION, GROUP, SCOPE_NAME, scope)
        self.scopeChanged.emit()

    @QtCore.Slot(str)
    def setScope(self, value: str) -> None:
        self._set_scope(value)

    scope = QtCore.Property(str, fget=_get_scope, fset=_set_scope, notify=scopeChanged)
