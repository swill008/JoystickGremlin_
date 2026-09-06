# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

from gremlin.config import Configuration
from gremlin.osc import (
    OSC_GROUP,
    OSC_SECTION,
    parse_delay_ms,
    local_ipv4_addresses,
)
from gremlin.ui.option import BaseMetaConfigOptionWidget, MetaConfigOption
import gremlin.ui.type_aliases as ta

QML_IMPORT_NAME = "Gremlin.Config"
QML_IMPORT_MAJOR_VERSION = 1


class OscAddressModel(QtCore.QAbstractListModel, BaseMetaConfigOptionWidget):
    """Dropdown of this PC's IPv4 addresses plus a refresh action."""

    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"name"),
    }
    currentIndexChanged = QtCore.Signal()

    config_name = "host"
    qml_file = "qml:OptionOscInputHost.qml"

    def __init__(self, parent: ta.OQO = None) -> None:
        QtCore.QAbstractListModel.__init__(self, parent)
        BaseMetaConfigOptionWidget.__init__(self)
        self._config = Configuration()
        self._addresses = local_ipv4_addresses()

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._addresses)

    def data(
        self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole
    ) -> str | None:
        if role == QtCore.Qt.ItemDataRole.UserRole + 1:
            return self._addresses[index.row()]
        return None

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles

    @QtCore.Slot()
    def refresh(self) -> None:
        self.beginResetModel()
        self._addresses = local_ipv4_addresses()
        self.endResetModel()
        self.currentIndexChanged.emit()

    def _get_current_index(self) -> int:
        current = str(
            self._config.value(OSC_SECTION, OSC_GROUP, self.config_name) or ""
        )
        try:
            return self._addresses.index(current)
        except ValueError:
            return 0

    def _set_current_index(self, index: int) -> None:
        if not (0 <= index < len(self._addresses)):
            return
        self._config.set(
            OSC_SECTION, OSC_GROUP, self.config_name, self._addresses[index]
        )
        self.currentIndexChanged.emit()

    currentIndex = QtCore.Property(
        int,
        fget=_get_current_index,
        fset=_set_current_index,
        notify=currentIndexChanged,
    )

    def _qml_path(self) -> str:
        return "file:///" + QtCore.QFile(self.qml_file).fileName()


@ta.QmlElement
class OscInputHostModel(OscAddressModel):
    config_name = "host"
    qml_file = "qml:OptionOscInputHost.qml"


@ta.QmlElement
class OscOutputHostModel(OscAddressModel):
    config_name = "output-host"
    qml_file = "qml:OptionOscOutputHost.qml"


@ta.QmlElement
class OscAutoreleaseModel(QtCore.QObject, BaseMetaConfigOptionWidget):
    """Autorelease delay in ms with EX preset buttons."""

    delayChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        QtCore.QObject.__init__(self, parent)
        BaseMetaConfigOptionWidget.__init__(self)
        self._config = Configuration()

    def _get_delay(self) -> str:
        raw = self._config.value(OSC_SECTION, OSC_GROUP, "autorelease-delay")
        return str(parse_delay_ms(raw))

    def _set_delay(self, value: str) -> None:
        delay = parse_delay_ms(value)
        self._config.set(OSC_SECTION, OSC_GROUP, "autorelease-delay", str(delay))
        self.delayChanged.emit()

    @QtCore.Slot(int)
    def setPreset(self, milliseconds: int) -> None:
        self._set_delay(str(milliseconds))

    delayMs = QtCore.Property(
        str, fget=_get_delay, fset=_set_delay, notify=delayChanged
    )

    def _qml_path(self) -> str:
        return "file:///" + QtCore.QFile("qml:OptionOscAutorelease.qml").fileName()


MetaConfigOption().register(
    OSC_SECTION,
    OSC_GROUP,
    "input-host",
    "Input IP Gremlin binds to. Refresh rescans this PC's addresses.",
    OscInputHostModel,
)
MetaConfigOption().register(
    OSC_SECTION,
    OSC_GROUP,
    "output-address",
    "Output IP for OSC feedback to Companion. Refresh rescans addresses.",
    OscOutputHostModel,
)
MetaConfigOption().register(
    OSC_SECTION,
    OSC_GROUP,
    "delay-presets",
    "Default Autorelease Delay. Presets match EX: 1/10s, 1/4s, 1/2s, 3/4s, 1s.",
    OscAutoreleaseModel,
)
