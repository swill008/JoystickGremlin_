# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from xml.etree import ElementTree

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.profile import InputItem
from gremlin.signal import signal
from gremlin import shared_state
from gremlin.ui.device import (
    Device,
    KeyboardManagerModel,
    LogicalDeviceManagementModel,
    QML_IMPORT_MAJOR_VERSION,
    QML_IMPORT_NAME,
)
from gremlin.ui.osc_device_model import OscDeviceManagementModel

assert QML_IMPORT_NAME == "Gremlin.Device"
assert QML_IMPORT_MAJOR_VERSION == 1

_orig_init = InputItem.__init__
_orig_from_xml = InputItem.from_xml
_orig_to_xml = InputItem.to_xml
_device_data = Device.data
_osc_data = OscDeviceManagementModel.data
_logical_data = LogicalDeviceManagementModel.data
_keyboard_data = KeyboardManagerModel.data


def _init(self, library) -> None:
    _orig_init(self, library)
    self.action_name = ""


def _from_xml(self, node: ElementTree.Element) -> None:
    _orig_from_xml(self, node)
    child = node.find("action-name")
    self.action_name = "" if child is None or child.text is None else child.text


def _to_xml(self) -> ElementTree.Element:
    node = _orig_to_xml(self)
    name = getattr(self, "action_name", "") or ""
    if name:
        child = ElementTree.SubElement(node, "action-name")
        child.text = name
    return node


def _description_from_item(item) -> str:
    if item is None:
        return ""
    return getattr(item, "action_name", "") or ""


def _set_item_name(item, name: str, index: int) -> None:
    if item is None:
        return
    item.action_name = (name or "").strip()
    signal.inputItemChanged.emit(index)


def apply_action_name(model: object, index: int, name: str) -> None:
    profile = shared_state.current_profile
    if profile is None or index < 0:
        return
    if isinstance(model, Device):
        if model._device is None:
            return
        info = model._convert_index(index)
        item = profile.get_input_item(
            model._device.device_guid.uuid, info[0], info[1], model._mode, True
        )
        _set_item_name(item, name, index)
        model.refreshInput(index)
        return
    if isinstance(model, OscDeviceManagementModel):
        info = model._index_to_input(index)
        item = profile.get_input_item(
            model._osc.device_guid, info.type, info.id, model._mode, True
        )
        _set_item_name(item, name, index)
        model.refreshInput(index)
        return
    if isinstance(model, LogicalDeviceManagementModel):
        label = model._logical.labels_of_type()[index]
        info = model._logical[label]
        item = profile.get_input_item(
            model._logical.device_guid, info.type, info.id, model._mode, True
        )
        _set_item_name(item, name, index)
        model.refreshInput(index)
        return
    if isinstance(model, KeyboardManagerModel):
        identifier = model.inputIdentifier(index)
        if identifier is None:
            return
        item = profile.get_input_item(
            identifier.device_guid,
            identifier.input_type,
            identifier.input_id,
            getattr(model, "_mode", "Default"),
            True,
        )
        _set_item_name(item, name, index)
        model.dataChanged.emit(
            model.createIndex(index, 0), model.createIndex(index, 0)
        )


def _patch_description(original, resolve_item):
    def data(self, index, role=QtCore.Qt.ItemDataRole.DisplayRole):
        raw = self.roles.get(role)
        role_name = raw.data().decode() if hasattr(raw, "data") else str(raw or "")
        if role_name == "description":
            try:
                item = resolve_item(self, index.row())
            except Exception:
                item = None
            return _description_from_item(item)
        return original(self, index, role)

    return data


def _device_item(self, row: int):
    return self._get_input_item(self._convert_index(row))


def _osc_item(self, row: int):
    info = self._index_to_input(row)
    profile = shared_state.current_profile
    if profile is None:
        return None
    return profile.get_input_item(
        self._osc.device_guid, info.type, info.id, self._mode, False
    )


def _logical_item(self, row: int):
    label = self._logical.labels_of_type()[row]
    info = self._logical[label]
    profile = shared_state.current_profile
    if profile is None:
        return None
    return profile.get_input_item(
        self._logical.device_guid, info.type, info.id, self._mode, False
    )


def _keyboard_item(self, row: int):
    identifier = self.inputIdentifier(row)
    profile = shared_state.current_profile
    if profile is None or identifier is None:
        return None
    return profile.get_input_item(
        identifier.device_guid,
        identifier.input_type,
        identifier.input_id,
        getattr(self, "_mode", "Default"),
        False,
    )


InputItem.__init__ = _init
InputItem.from_xml = _from_xml
InputItem.to_xml = _to_xml
Device.data = _patch_description(_device_data, _device_item)
OscDeviceManagementModel.data = _patch_description(_osc_data, _osc_item)
LogicalDeviceManagementModel.data = _patch_description(_logical_data, _logical_item)
KeyboardManagerModel.data = _patch_description(_keyboard_data, _keyboard_item)


@ta.QmlElement
class ActionNames(QtCore.QObject):
    @QtCore.Slot("QVariant", int, str)
    def setOnModel(self, model: object, index: int, name: str) -> None:
        apply_action_name(model, index, name)
