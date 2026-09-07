# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import time

from PySide6 import QtCore

from gremlin.osc import OscRuntime
from gremlin.ui.osc_device_model import OscDeviceManagementModel

_DEBOUNCE_S = 0.3

_orig_listen_once = OscRuntime.listen_once
_orig_cancel = OscRuntime.cancel_listen
_orig_stop = OscRuntime.stop
_orig_on_main = OscRuntime._on_main
_orig_learned = OscDeviceManagementModel._on_learned
_orig_cancel_model = OscDeviceManagementModel.cancelListen
_orig_listen_cmd = OscDeviceManagementModel.listenForCommand


def listen_once(self) -> bool:
    self._hold_learn = False
    return _orig_listen_once(self)


def listen_bulk(self) -> bool:
    self._hold_learn = True
    return _orig_listen_once(self)


def cancel_listen(self) -> None:
    self._hold_learn = False
    _orig_cancel(self)


def stop(self) -> None:
    self._hold_learn = False
    _orig_stop(self)


def _on_main(self, address: str, args: object) -> None:
    hold = bool(getattr(self, "_hold_learn", False))
    _orig_on_main(self, address, args)
    if hold:
        self._learn = True
        self.listenChanged.emit()


def model_listen_for_command(self) -> None:
    self._bulk = False
    _orig_listen_cmd(self)


def model_listen_for_bulk(self, type_str: str) -> None:
    self._capture_only = True
    self._bulk = True
    self._bulk_mode = type_str or "Button"
    self._last_bulk_addr = ""
    self._last_bulk_time = 0.0
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


OscRuntime.listen_once = listen_once
OscRuntime.listen_bulk = listen_bulk
OscRuntime.cancel_listen = cancel_listen
OscRuntime.stop = stop
OscRuntime._on_main = _on_main
OscDeviceManagementModel.listenForCommand = model_listen_for_command
OscDeviceManagementModel.listenForBulk = QtCore.Slot(str)(model_listen_for_bulk)
OscDeviceManagementModel.cancelListen = model_cancel_listen
OscDeviceManagementModel._on_learned = model_on_learned
