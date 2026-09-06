# -*- coding: utf-8; -*-

# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import codecs
import dataclasses
import hashlib
import logging
import os
import uuid
from abc import (
    ABCMeta,
    abstractmethod,
)
from collections.abc import Iterable
from pathlib import Path
from typing import (
    TYPE_CHECKING,
    Callable,
)
from xml.dom import minidom
from xml.etree import ElementTree

import dill
from gremlin import (
    device_initialization,
    error,
    plugin_manager,
    signal,
)
from gremlin.logical_device import LogicalDevice
from gremlin.osc import OscDevice
from gremlin.tree import TreeNode
from gremlin.types import (
    AxisButtonDirection,
    HatDirection,
    InputType,
    ScanCode,
)
from gremlin.user_script import Script
from gremlin.util import (
    clamp,
    create_subelement_node,
    create_subelement_node_custom,
    read_action_ids,
    read_subelement,
    read_subelement_custom,
    safe_format,
    safe_read,
)

if TYPE_CHECKING:
    from gremlin.base_classes import AbstractActionData
