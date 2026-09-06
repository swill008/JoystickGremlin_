# -*- coding: utf-8 -*-
# SPDX-License-Identifier: GPL-3.0-only
"""OSC virtual device + UDP listener for Path B.

Does not write vJoy. Inputs are buttons/axes keyed by OSC address.
"""

from __future__ import annotations

import logging
import threading
import uuid
from collections.abc import Callable
from typing import Any

from gremlin.common import SingletonMetaclass
from gremlin.error import GremlinError
from gremlin.types import InputType

log = logging.getLogger("system")

OSC_DEVICE_GUID = "a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70"
OSC_DEVICE_UUID = uuid.UUID(OSC_DEVICE_GUID)

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9000

MessageCallback = Callable[[str, tuple[Any, ...]], None]


def is_pressed(args: tuple[Any, ...]) -> bool:
    """EX button rule: first numeric arg != 0 is press."""
    if not args:
        return True
    value = args[0]
    try:
        return float(value) != 0.0
    except (TypeError, ValueError):
        return bool(value)


def axis_value(args: tuple[Any, ...]) -> float:
    if not args:
        return 0.0
    try:
        return float(args[0])
    except (TypeError, ValueError):
        return 0.0


class OscDevice(metaclass=SingletonMetaclass):
    """User-defined OSC addresses that act like joystick inputs."""

    device_guid = OSC_DEVICE_UUID

    class Input:
        def __init__(self, label: str, input_id: int, input_type: InputType) -> None:
            self.label = label
            self.id = input_id
            self.type = input_type
            self.value: float | bool = (
                0.0 if input_type == InputType.JoystickAxis else False
            )

    def __init__(self) -> None:
        self._inputs: dict[str, OscDevice.Input] = {}
        self._by_id: dict[tuple[InputType, int], str] = {}

    def reset(self) -> None:
        self._inputs = {}
        self._by_id = {}

    def create(
        self,
        input_type: InputType,
        label: str | None = None,
        input_id: int | None = None,
    ) -> OscDevice.Input:
        if input_type not in (InputType.JoystickAxis, InputType.JoystickButton):
            raise GremlinError(f"OSC inputs must be axis or button, got {input_type}")
        if input_id is None:
            used = {item.id for item in self._inputs.values() if item.type == input_type}
            input_id = 1
            while input_id in used:
                input_id += 1
        if label is None:
            prefix = "/osc/axis" if input_type == InputType.JoystickAxis else "/osc/button"
            label = f"{prefix}/{input_id}"
        label = label.casefold()
        if label in self._inputs:
            raise GremlinError(f"OSC address '{label}' already exists")
        item = OscDevice.Input(label, input_id, input_type)
        self._inputs[label] = item
        self._by_id[(input_type, input_id)] = label
        return item

    def set_label(self, old_label: str, new_label: str) -> None:
        old_label = old_label.casefold()
        new_label = new_label.casefold()
        if old_label == new_label:
            return
        if old_label not in self._inputs:
            raise GremlinError(f"No OSC input '{old_label}'")
        if new_label in self._inputs:
            raise GremlinError(f"OSC address '{new_label}' already exists")
        item = self._inputs.pop(old_label)
        item.label = new_label
        self._inputs[new_label] = item
        self._by_id[(item.type, item.id)] = new_label

    def delete(self, label: str) -> None:
        label = label.casefold()
        item = self._inputs.pop(label)
        del self._by_id[(item.type, item.id)]

    def labels_of_type(self, type_list: list[InputType] | None = None) -> list[str]:
        if not type_list:
            type_list = [InputType.JoystickAxis, InputType.JoystickButton]
        labels = [
            item.label
            for item in sorted(self._inputs.values(), key=lambda x: (x.type.name, x.id))
            if item.type in type_list
        ]
        return labels

    def find_address(self, address: str) -> OscDevice.Input | None:
        return self._inputs.get((address or "").casefold())

    def __getitem__(self, label: str) -> OscDevice.Input:
        label = label.casefold()
        if label not in self._inputs:
            raise GremlinError(f"No OSC input '{label}'")
        return self._inputs[label]


class OscListener:
    """UDP OSC server on a background thread."""

    def __init__(
        self,
        host: str = DEFAULT_HOST,
        port: int = DEFAULT_PORT,
        callback: MessageCallback | None = None,
    ) -> None:
        self.host = host
        self.port = port
        self.callback = callback
        self._server = None
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._server is not None:
            return
        try:
            from pythonosc.dispatcher import Dispatcher
            from pythonosc.osc_server import ThreadingOSCUDPServer
        except ImportError as exc:
            raise RuntimeError(
                "python-osc is required. pip install python-osc"
            ) from exc

        dispatcher = Dispatcher()
        dispatcher.set_default_handler(self._on_message)
        self._server = ThreadingOSCUDPServer((self.host, self.port), dispatcher)
        self._thread = threading.Thread(
            target=self._server.serve_forever,
            name="gremlin-osc",
            daemon=True,
        )
        self._thread.start()
        log.info("OSC listening on %s:%s", self.host, self.port)

    def stop(self) -> None:
        if self._server is None:
            return
        self._server.shutdown()
        self._server.server_close()
        self._server = None
        self._thread = None
        log.info("OSC listener stopped")

    def _on_message(self, address: str, *args: Any) -> None:
        address = (address or "").casefold()
        if address == "/noop":
            return
        if self.callback is not None:
            self.callback(address, args)
