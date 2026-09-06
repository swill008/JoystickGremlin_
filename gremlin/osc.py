# -*- coding: utf-8 -*-
# SPDX-License-Identifier: GPL-3.0-only
"""OSC virtual device, UDP listener, and event inject for Path B."""

from __future__ import annotations

import logging
import socket
import threading
import uuid
from collections.abc import Callable
from typing import Any

from PySide6 import QtCore

from gremlin.common import SingletonDecorator, SingletonMetaclass
from gremlin.error import GremlinError
from gremlin.types import InputType

log = logging.getLogger("system")

OSC_DEVICE_GUID = "a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70"
OSC_DEVICE_UUID = uuid.UUID(OSC_DEVICE_GUID)

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8000

MessageCallback = Callable[[str, tuple[Any, ...]], None]


def local_ipv4_addresses() -> list[str]:
    """This machine's IPv4 addresses, plus loopback and all-interfaces."""
    found: list[str] = []

    def add(ip: str) -> None:
        if ip and ip not in found:
            found.append(ip)

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            add(sock.getsockname()[0])
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            add(info[4][0])
    except OSError:
        pass
    add("127.0.0.1")
    add("0.0.0.0")
    return found


def default_bind_host() -> str:
    for ip in local_ipv4_addresses():
        if ip not in ("127.0.0.1", "0.0.0.0"):
            return ip
    return DEFAULT_HOST


def is_pressed(args: tuple[Any, ...]) -> bool:
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
        value = float(args[0])
    except (TypeError, ValueError):
        return 0.0
    return max(-1.0, min(1.0, value))


def parse_port(value: Any) -> int:
    text = str(value or "").replace(",", "").strip()
    try:
        port = int(text)
    except ValueError:
        return DEFAULT_PORT
    if 1 <= port <= 65535:
        return port
    return DEFAULT_PORT


def guess_input_type(args: tuple[Any, ...]) -> InputType:
    if not args:
        return InputType.JoystickButton
    try:
        value = float(args[0])
    except (TypeError, ValueError):
        return InputType.JoystickButton
    if value in (0.0, 1.0) or abs(value) > 1.0:
        return InputType.JoystickButton
    return InputType.JoystickAxis


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
        label = str(label).casefold()
        if label in self._inputs:
            raise GremlinError(f"OSC address '{label}' already exists")
        item = OscDevice.Input(label, int(input_id), input_type)
        self._inputs[label] = item
        self._by_id[(input_type, int(input_id))] = label
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
        return [
            item.label
            for item in sorted(self._inputs.values(), key=lambda x: (x.type.name, x.id))
            if item.type in type_list
        ]

    def find_address(self, address: str) -> OscDevice.Input | None:
        return self._inputs.get((address or "").casefold())

    def find_by_id(
        self, input_type: InputType, input_id: int
    ) -> OscDevice.Input | None:
        label = self._by_id.get((input_type, int(input_id)))
        if label is None:
            return None
        return self._inputs.get(label)

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
        from pythonosc.dispatcher import Dispatcher
        from pythonosc.osc_server import ThreadingOSCUDPServer

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


@SingletonDecorator
class OscRuntime(QtCore.QObject):
    """Starts the OSC listener while a profile is active and injects Events."""

    incoming = QtCore.Signal(str, object)
    learned = QtCore.Signal(str, object)
    listenChanged = QtCore.Signal()

    def __init__(self) -> None:
        super().__init__()
        self._listener: OscListener | None = None
        self._learn = False
        self.incoming.connect(self._on_main)

    def is_listening(self) -> bool:
        return self._learn

    def listen_once(self) -> bool:
        """Capture the next OSC packet so the UI can bind it as an input."""
        from gremlin.signal import signal as ui_signal

        self.start()
        if self._listener is None:
            self._learn = False
            self.listenChanged.emit()
            ui_signal.showError.emit(
                "Could not start OSC listener.",
                "Enable OSC in Options and check host/port.",
            )
            return False
        self._learn = True
        self.listenChanged.emit()
        log.info("OSC listen-once waiting for next packet")
        return True

    def cancel_listen(self) -> None:
        if not self._learn:
            return
        self._learn = False
        self.listenChanged.emit()
        log.info("OSC listen-once cancelled")

    def start(self) -> None:
        self.stop()
        from gremlin.config import Configuration
        from gremlin.signal import signal as ui_signal

        cfg = Configuration()
        enabled = True
        host = default_bind_host()
        port = DEFAULT_PORT
        if cfg.exists("global", "osc", "enabled"):
            enabled = bool(cfg.value("global", "osc", "enabled"))
        if cfg.exists("global", "osc", "host"):
            host = str(cfg.value("global", "osc", "host") or host).strip()
        if cfg.exists("global", "osc", "port"):
            port = parse_port(cfg.value("global", "osc", "port"))
        if not enabled:
            log.info("OSC listener disabled in options")
            return
        try:
            self._listener = OscListener(host, port, self._from_thread)
            self._listener.start()
        except ImportError:
            ui_signal.showError.emit(
                "OSC requires python-osc.",
                "In the repo folder run: poetry add python-osc",
            )
            self._listener = None
        except OSError as exc:
            ui_signal.showError.emit(
                f"Could not bind OSC on {host}:{port}.",
                str(exc),
            )
            self._listener = None

    def stop(self) -> None:
        self._learn = False
        self.listenChanged.emit()
        if self._listener is None:
            return
        self._listener.stop()
        self._listener = None

    def _from_thread(self, address: str, args: tuple[Any, ...]) -> None:
        self.incoming.emit(address, args)

    def _on_main(self, address: str, args: object) -> None:
        from gremlin.event_handler import Event, EventListener
        from gremlin.mode_manager import ModeManager

        payload = args if isinstance(args, tuple) else ()
        if self._learn:
            self._learn = False
            self.listenChanged.emit()
            log.info("OSC listen captured %s %s", address, payload)
            self.learned.emit(address, payload)

        item = OscDevice().find_address(address)
        if item is None:
            log.debug("OSC ignored unmatched address %s %s", address, args)
            return
        log.debug("OSC %s %s -> %s %s", address, args, item.type.name, item.id)
        mode = ModeManager().current.name
        if item.type == InputType.JoystickButton:
            pressed = is_pressed(payload)
            item.value = pressed
            EventListener().joystick_event.emit(
                Event(
                    event_type=InputType.JoystickButton,
                    identifier=item.id,
                    device_guid=OSC_DEVICE_UUID,
                    mode=mode,
                    is_pressed=pressed,
                )
            )
        elif item.type == InputType.JoystickAxis:
            value = axis_value(payload)
            item.value = value
            EventListener().joystick_event.emit(
                Event(
                    event_type=InputType.JoystickAxis,
                    identifier=item.id,
                    device_guid=OSC_DEVICE_UUID,
                    mode=mode,
                    value=value,
                    raw_value=value,
                )
            )
