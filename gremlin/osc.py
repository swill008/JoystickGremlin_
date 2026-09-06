# -*- coding: utf-8 -*-
# SPDX-License-Identifier: GPL-3.0-only
"""In-process OSC listener for Path B (R15 UI + EX behavior).

Does not write vJoy. Callers receive (address, args) and turn that into
an R15 Event or Logical Device update.
"""

from __future__ import annotations

import logging
import threading
from collections.abc import Callable
from typing import Any

log = logging.getLogger("system")

# Reserved GUID for the future OSC device tab (distinct from Logical Device).
OSC_DEVICE_GUID = "a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70"

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
