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


def _read_item(model: object, index: int, create: bool):
    profile = shared_state.current_profile
    if profile is None or index < 0:
        return None
    if hasattr(model, "_convert_index") and hasattr(model, "_device"):
        if getattr(model, "_device", None) is None:
            return None
        info = model._convert_index(index)
        return profile.get_input_item(
            model._device.device_guid.uuid,
            info[0],
            info[1],
            getattr(model, "_mode", "Default"),
            create,
        )
    if hasattr(model, "_index_to_input") and hasattr(model, "_osc"):
        info = model._index_to_input(index)
        return profile.get_input_item(
            model._osc.device_guid,
            info.type,
            info.id,
            getattr(model, "_mode", "Default"),
            create,
        )
    if hasattr(model, "_logical"):
        labels = model._logical.labels_of_type()
        if index >= len(labels):
            return None
        info = model._logical[labels[index]]
        return profile.get_input_item(
            model._logical.device_guid,
            info.type,
            info.id,
            getattr(model, "_mode", "Default"),
            create,
        )
    if hasattr(model, "inputIdentifier"):
        identifier = model.inputIdentifier(index)
        if identifier is None:
            return None
        return profile.get_input_item(
            identifier.device_guid,
            identifier.input_type,
            identifier.input_id,
            getattr(model, "_mode", "Default"),
            create,
        )
    return None


def apply_action_name(model: object, index: int, name: str) -> None:
    item = _read_item(model, index, True)
    _set_item_name(item, name, index)
    if hasattr(model, "refreshInput"):
        model.refreshInput(index)
    elif hasattr(model, "dataChanged") and hasattr(model, "createIndex"):
        model.dataChanged.emit(model.createIndex(index, 0), model.createIndex(index, 0))


def read_action_name(model: object, index: int) -> str:
    return _description_from_item(_read_item(model, index, False))


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
    return _read_item(self, row, False)


def _logical_item(self, row: int):
    return _read_item(self, row, False)


def _keyboard_item(self, row: int):
    return _read_item(self, row, False)


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

    @QtCore.Slot("QVariant", int, result=str)
    def getOnModel(self, model: object, index: int) -> str:
        return read_action_name(model, index)
