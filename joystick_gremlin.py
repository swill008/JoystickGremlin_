# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import argparse
import ctypes
import logging
import logging.handlers
import os
import subprocess
import sys
import time
import traceback
import types
from pathlib import Path
from typing import Any

from PySide6 import (
    QtCore,
    QtGui,
    QtQml,
    QtQuick,
    QtWidgets,
)

import dill
import resources  # noqa: F401
import vjoy.vjoy
from gremlin.config import Configuration
from gremlin.types import PropertyType

install_path = os.path.normcase(os.path.dirname(os.path.abspath(sys.argv[0])))
os.chdir(install_path)

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Universal"

import gremlin.util

sys.path.insert(0, gremlin.util.userprofile_path())
gremlin.util.setup_userprofile()

import gremlin.audio_player
import gremlin.config
import gremlin.device_initialization
import gremlin.error
import gremlin.event_handler
import gremlin.mode_manager
import gremlin.plugin_manager
import gremlin.signal
import gremlin.tts
import gremlin.types
import gremlin.ui.action_image_generator
import gremlin.ui.backend
import gremlin.ui.system_tray
import gremlin.ui.option
import gremlin.ui.osc_option  # noqa: F401
import gremlin.ui.log_option  # noqa: F401
import gremlin.ui.tools
import gremlin.ui.util
import gremlin.osc
import gremlin.ui.osc_device_model  # noqa: F401
import gremlin.ui.device_names  # noqa: F401
import gremlin.osc_persist  # noqa: F401


def configure_logger(config: dict[str, Any]) -> None:
    logger = logging.getLogger(config["name"])
    logger.setLevel(config["level"])
    if config["mode"] == "rotate":
        handler = logging.handlers.RotatingFileHandler(
            config["logfile"], maxBytes=1 * 1024 * 1024, backupCount=1
        )
    elif config["mode"] == "session":
        handler = logging.FileHandler(config["logfile"], mode="w")
    else:
        raise gremlin.error.GremlinError(f"Invalid logging mode: {config['mode']}")
    handler.setLevel(config["level"])
    formatter = logging.Formatter(config["format"], "%Y-%m-%d %H:%M:%S")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    if config["mode"] != "session":
        logger.debug("-" * 80)
        logger.debug(time.strftime("%Y-%m-%d %H:%M"))
        logger.debug(f"Starting Joystick Gremlin {gremlin.util.get_code_release()}-OSC")
        logger.debug("-" * 80)


def exception_hook(
    exception_type: type[BaseException],
    value: BaseException,
    trace: types.TracebackType | None,
) -> None:
    msg = " ".join(traceback.format_exception(exception_type, value, trace))
    logging.getLogger("system").error(f"Unhandled exception: {msg}")
    try:
        gremlin.signal.display_error("An unhandled exception occured.", msg)
    except RuntimeError:
        pass


def shutdown_cleanup() -> None:
    """Stop runtime threads and virtual devices so File/Exit does not leave a process."""
    log = logging.getLogger("system")
    try:
        listener = gremlin.event_handler.EventListener()
        timer = getattr(listener, "_device_update_timer", None)
        if timer is not None:
            try:
                timer.cancel()
            except Exception:
                pass
            listener._device_update_timer = None
        listener.terminate()
        mouse_hook = getattr(listener, "mouse_hook", None)
        if mouse_hook is not None:
            try:
                mouse_hook.stop()
            except Exception:
                pass
    except Exception:
        log.exception("Shutdown: event listener")
    try:
        backend = gremlin.ui.backend.Backend()
        if backend.gremlinActive:
            backend.activate_gremlin(False)
        backend.runner.stop()
        backend.process_monitor.stop()
    except Exception:
        log.exception("Shutdown: backend")
    try:
        from vigem.xbox import XboxProxy
        XboxProxy().reset()
    except Exception:
        pass
    try:
        vjoy.vjoy.VJoyProxy.reset()
    except Exception:
        log.exception("Shutdown: vJoy")
    try:
        gremlin.audio_player.AudioPlayer().stop()
    except Exception:
        pass
    try:
        gremlin.tts.TTSManager().stop()
    except Exception:
        pass
    try:
        gremlin.osc.OscRuntime().stop()
    except Exception:
        log.exception("Shutdown: OSC")
