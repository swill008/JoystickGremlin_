# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import time

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.osc import OscRuntime
from gremlin.ui.device import QML_IMPORT_MAJOR_VERSION, QML_IMPORT_NAME
from gremlin.ui.osc_device_model import OscDeviceManagementModel

assert QML_IMPORT_NAME == "Gremlin.Device"
assert QML_IMPORT_MAJOR_VERSION == 1

_DEBOUNCE_S = 0.3

_orig_learned = OscDeviceManagementModel._on_learned
_orig_cancel_model = OscDeviceManagementModel.cancelListen
_orig_listen_cmd = OscDeviceManagementModel.listenForCommand


def model_listen_for_command(self) -> None:
    self._bulk = False
    _orig_listen_cmd(self)


def start_bulk(model: OscDeviceManagementModel, type_str: str) -> None:
    model._capture_only = True
    model._bulk = True
    model._bulk_mode = type_str or "Button"
    model._last_bulk_addr = ""
    model._last_bulk_time = 0.0
    OscRuntime().listen_bulk()


def model_cancel_listen(self) -> None:
    self._bulk = False
    _orig_cancel_model(self)


def model_on_learned(self, address: str, args: object) -> None:
    if getattr(self, "_bulk", False):
        now = time.monotonic()
        key = (address or "").casefold()
        if key == getattr(self, "_last_bulk_addr", "") and (
            now - getattr(self, "_last_bulk_time", 0.0) < _DEBOUNCE_S
        ):
            return
        self._last_bulk_addr = key
        self._last_bulk_time = now
        payload = args if isinstance(args, tuple) else ()
        shown = ", ".join(str(item) for item in payload)
        self.commandCaptured.emit(address, shown)
        self.createMappedInput(getattr(self, "_bulk_mode", "Button"), address)
        return
    _orig_learned(self, address, args)


OscDeviceManagementModel.listenForCommand = model_listen_for_command
OscDeviceManagementModel.cancelListen = model_cancel_listen
OscDeviceManagementModel._on_learned = model_on_learned


@ta.QmlElement
class OscBulkCapture(QtCore.QObject):
    @QtCore.Slot("QVariant", str)
    def start(self, model: object, type_str: str) -> None:
        if model is None:
            return
        start_bulk(model, type_str)
