# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

import gremlin.action_label  # noqa: F401
import gremlin.osc_bulk  # noqa: F401
import gremlin.ui.osc_settings_info  # noqa: F401
import gremlin.ui.vjoy_status  # noqa: F401
import gremlin.ui.live_input  # noqa: F401
import gremlin.ui.highlight_option  # noqa: F401
import gremlin.ui.window_placement  # noqa: F401
import gremlin.ui.input_pairing  # noqa: F401
import gremlin.ui.type_aliases as ta
from gremlin.config import Configuration
from gremlin.types import PropertyType
from gremlin.ui.device import QML_IMPORT_MAJOR_VERSION, QML_IMPORT_NAME

assert QML_IMPORT_NAME == "Gremlin.Device"
assert QML_IMPORT_MAJOR_VERSION == 1

SECTION = "devices"
GROUP = "display"
NAME = "aliases"

_CACHE: dict[str, str] | None = None


def _ensure() -> Configuration:
    cfg = Configuration()
    if not cfg.exists(SECTION, GROUP, NAME):
        cfg.register(
            SECTION,
            GROUP,
            NAME,
            PropertyType.List,
            [],
            "Friendly display names for devices and inputs.",
            {},
            False,
        )
    return cfg


def _load() -> dict[str, str]:
    global _CACHE
    if _CACHE is not None:
        return _CACHE
    raw = _ensure().value(SECTION, GROUP, NAME) or []
    names: dict[str, str] = {}
    for entry in raw:
        if isinstance(entry, list) and len(entry) >= 2:
            key = str(entry[0]).strip()
            value = str(entry[1]).strip()
            if key:
                names[key] = value
    _CACHE = names
    return names


def _save(names: dict[str, str]) -> None:
    global _CACHE
    _CACHE = dict(names)
    rows = [[key, value] for key, value in names.items() if value]
    _ensure().set(SECTION, GROUP, NAME, rows)


def display_name(key: str, default: str) -> str:
    alias = _load().get(str(key).strip(), "").strip()
    return alias or default


def set_alias(key: str, value: str) -> None:
    names = dict(_load())
    key = str(key).strip()
    text = str(value or "").strip()
    if text:
        names[key] = text
    else:
        names.pop(key, None)
    _save(names)


@ta.QmlElement
class DeviceNames(QtCore.QObject):
    changed = QtCore.Signal()

    @QtCore.Slot(str, str, result=str)
    def display(self, key: str, default: str) -> str:
        return display_name(key, default)

    @QtCore.Slot(str, str)
    def setAlias(self, key: str, value: str) -> None:
        set_alias(key, value)
        self.changed.emit()
