# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import logging
import os
import sys
import time
from abc import (
    ABCMeta,
    abstractmethod,
)

import dill
from gremlin import (
    audio_player,
    device_initialization,
    error,
    event_handler,
    event_helpers,
    fsm,
    input_cache,
    macro,
    mode_manager,
    profile,
    sendinput,
    signal,
    tts,
    user_script,
)
from gremlin.base_classes import Value
from gremlin.config import Configuration
from gremlin.input_refresh import RefreshPhysicalInputs
from gremlin.osc import OscRuntime
from gremlin.types import (
    ActionProperty,
    AxisButtonDirection,
    HatDirection,
    InputType,
)
from vigem.xbox import XboxProxy
from vjoy.vjoy import VJoyProxy
