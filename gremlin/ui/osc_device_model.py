# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from typing import cast

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.config import Configuration
from gremlin.error import GremlinError
from gremlin.osc import OSC_DEVICE_UUID, OscDevice
from gremlin.profile import InputItem
from gremlin.signal import signal
from gremlin.types import InputType
from gremlin import shared_state
from gremlin.ui.device import (
    InputIdentifier,
    QML_IMPORT_NAME,
    QML_IMPORT_MAJOR_VERSION,
    _description_from_item,
    _generate_action_sequence_descriptor,
)

assert QML_IMPORT_NAME == "Gremlin.Device"
assert QML_IMPORT_MAJOR_VERSION == 1


class OscInputIdentifier(InputIdentifier):
    """InputIdentifier that does not query DILL for the virtual OSC device."""

    @QtCore.Property(str, notify=InputIdentifier.changed)
    def label(self) -> str:
        if not self.isValid:
            return "No input"
        item = OscDevice().find_by_id(self.input_type, int(self.input_id))
        if item is not None:
            return f"OSC - {item.label}"
        return (
            f"OSC - {InputType.to_string(self.input_type).capitalize()} "
            f"{self.input_id}"
        )

    @property
    def linear_index(self) -> int:
        if not self.isValid:
            raise GremlinError("Cannot compute linear index of invalid input")
        return max(int(self.input_id) - 1, 0)


@ta.QmlElement
class OscDeviceManagementModel(QtCore.QAbstractListModel):
    """Model for the OSC virtual input device tab."""

    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"name"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"label"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"actionSequenceCount"),
        QtCore.Qt.ItemDataRole.UserRole + 4: QtCore.QByteArray(
            b"actionSequenceDescriptor"
        ),
        QtCore.Qt.ItemDataRole.UserRole + 5: QtCore.QByteArray(
            b"actionSequenceDisplayMode"
        ),
        QtCore.Qt.ItemDataRole.UserRole + 6: QtCore.QByteArray(b"description"),
    }

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._osc = OscDevice()
        self._mode: str = "Default"
        signal.profileChanged.connect(self._profile_changed_cb)
        signal.inputItemChanged.connect(self.refreshInput)
        signal.oscDeviceModified.connect(self._full_refresh)

    @QtCore.Slot(str)
    def createInput(self, type_str: str) -> None:
        self.beginInsertRows(QtCore.QModelIndex(), self.rowCount(), self.rowCount())
        self._osc.create(InputType.to_enum(type_str))
        self.endInsertRows()
        self.dataChanged.emit(
            self.createIndex(0, 0), self.createIndex(self.rowCount(), 0)
        )
        signal.oscDeviceModified.emit()

    @QtCore.Slot(str, str)
    def changeName(self, old_label: str, new_label: str) -> None:
        try:
            self._osc.set_label(old_label, new_label)
            self.dataChanged.emit(
                self.createIndex(0, 0), self.createIndex(self.rowCount(), 0)
            )
            signal.oscDeviceModified.emit()
        except GremlinError:
            pass

    @QtCore.Slot(str)
    def deleteInput(self, label: str) -> None:
        item_index = self._label_to_index(label)
        self.beginRemoveRows(QtCore.QModelIndex(), item_index, item_index)
        self._osc.delete(label)
        self.endRemoveRows()
        self.dataChanged.emit(
            self.createIndex(0, 0), self.createIndex(self.rowCount(), 0)
        )
        signal.oscDeviceModified.emit()

    @QtCore.Slot(str)
    def setMode(self, mode: str) -> None:
        self._mode = mode
        self.dataChanged.emit(
            self.createIndex(0, 0), self.createIndex(self.rowCount() - 1, 0)
        )

    @QtCore.Slot(int)
    def refreshInput(self, index: int) -> None:
        self.dataChanged.emit(self.createIndex(index, 0), self.createIndex(index, 0))

    def _full_refresh(self) -> None:
        self.beginResetModel()
        self.endResetModel()

    def _get_guid(self) -> str:
        return str(self._osc.device_guid)

    def _profile_changed_cb(self) -> None:
        self.beginResetModel()
        self.endResetModel()

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._osc.labels_of_type())

    def data(
        self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole
    ) -> str | int:
        if role not in self.roles:
            return "Unknown"
        input_info = self._index_to_input(index.row())
        input_item: InputItem | None = None
        if shared_state.current_profile is not None:
            input_item = shared_state.current_profile.get_input_item(
                self._osc.device_guid, input_info.type, input_info.id, self._mode
            )
        match cast(str, self.roles[role]):
            case "name":
                return (
                    f"{InputType.to_string(input_info.type).capitalize()} "
                    f"{input_info.id} - {input_info.label}"
                )
            case "label":
                return input_info.label
            case "actionSequenceCount":
                return len(input_item.action_sequences) if input_item else 0
            case "actionSequenceDescriptor":
                return (
                    _generate_action_sequence_descriptor(input_item)
                    if input_item
                    else ""
                )
            case "actionSequenceDisplayMode":
                return Configuration().value(
                    "global", "general", "action-sequence-information"
                )
            case "description":
                return _description_from_item(input_item) if input_item else ""
            case _:
                return ""

    @QtCore.Slot(int, result=InputIdentifier)
    def inputIdentifier(self, index: int) -> InputIdentifier:
        if index < 0:
            return OscInputIdentifier(parent=self)
        item = self._index_to_input(index)
        identifier = OscInputIdentifier(parent=self)
        identifier.device_guid = self._osc.device_guid
        identifier.input_type = item.type
        identifier.input_id = item.id
        return identifier

    def _index_to_input(self, index: int):
        return self._osc[self._osc.labels_of_type()[index]]

    def _label_to_index(self, label: str) -> int:
        return self._osc.labels_of_type().index(label)

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles

    guid = QtCore.Property(str, fget=_get_guid)
