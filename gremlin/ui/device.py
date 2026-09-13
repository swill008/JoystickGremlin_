# -*- coding: utf-8; -*-

# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import logging
import math
import time
import uuid
from collections import OrderedDict
from dataclasses import dataclass
from typing import cast

from PySide6 import (
    QtCharts,
    QtCore,
)

import dill
import gremlin.ui.type_aliases as ta
from gremlin import (
    common,
    device_initialization,
    event_handler,
    keyboard,
    shared_state,
    util,
)
from gremlin.base_classes import AbstractActionData
from gremlin.config import Configuration
from gremlin.error import GremlinError
from gremlin.input_cache import DeviceDatabase
from gremlin.logical_device import LogicalDevice
from gremlin.profile import InputItem
from gremlin.signal import signal
from gremlin.types import (
    InputType,
    PropertyType,
    ScanCode,
)
from gremlin.ui import backend

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1


def _generate_action_sequence_descriptor(item: InputItem) -> str:
    icons = []
    if item is not None:
        for seq in item.action_sequences:
            [
                _collect_action_icons(action, icons)
                for action in seq.root_action.get_actions()[0]
            ]
    return ":".join(icons)


def _collect_action_icons(action: AbstractActionData, icons: list[str]) -> None:
    icons.append(action.icon)
    if action.tag == "map-to-vjoy":
        type_lookup = {
            InputType.JoystickAxis: "A",
            InputType.JoystickButton: "B",
            InputType.JoystickHat: "H",
            InputType.Invalid: "I",
        }
        icons[-1] += (
            f",{action.vjoy_device_id},"
            f"{type_lookup[action.vjoy_input_type]},"
            f"{action.vjoy_input_id}"
        )
    elif action.tag == "map-to-xbox":
        target = getattr(action, "xbox_target", None)
        target_value = target.value if hasattr(target, "value") else str(target or "a")
        pad_id = getattr(action, "xbox_device_id", 1)
        icons[-1] += f",{pad_id},{target_value}"
    for selector in action._valid_selectors():
        icons.append("(")
        [
            _collect_action_icons(child, icons)
            for child in action._get_container(selector)
        ]
        icons.append(")")
