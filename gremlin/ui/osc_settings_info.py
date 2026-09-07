# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.config import Configuration
from gremlin.osc import (
    DEFAULT_HOST,
    DEFAULT_OUTPUT_PORT,
    DEFAULT_PORT,
    default_bind_host,
    osc_option,
    parse_port,
)
from gremlin.ui.device import QML_IMPORT_MAJOR_VERSION, QML_IMPORT_NAME

assert QML_IMPORT_NAME == "Gremlin.Device"
assert QML_IMPORT_MAJOR_VERSION == 1


@ta.QmlElement
class OscSettingsInfo(QtCore.QObject):
    @QtCore.Slot(result=str)
    def summary(self) -> str:
        cfg = Configuration()
        enabled = osc_option(cfg, "enabled")
        if enabled is None:
            enabled = True
        host = str(osc_option(cfg, "host") or default_bind_host())
        port = parse_port(osc_option(cfg, "port"), DEFAULT_PORT)
        out_host = str(osc_option(cfg, "output-host") or DEFAULT_HOST)
        out_port = parse_port(osc_option(cfg, "output-port"), DEFAULT_OUTPUT_PORT)
        return (
            f"OSC enabled: {'Yes' if enabled else 'No'}\n"
            f"Input host: {host}\n"
            f"Input port: {port}\n"
            f"Output host: {out_host}\n"
            f"Output port: {out_port}\n\n"
            "Send the OSC packet to the input host and port."
        )
