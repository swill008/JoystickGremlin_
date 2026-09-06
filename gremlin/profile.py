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


class AbstractVirtualButton(metaclass=ABCMeta):
    """Base class of all virtual buttons."""

    def __init__(self) -> None:
        """Creates a new instance."""
        pass

    @abstractmethod
    def from_xml(self, node: ElementTree.Element) -> None:
        """Populates the virtual button based on the node's data.

        Args:
            node: the XML node containing data for this instance
        """
        pass

    @abstractmethod
    def to_xml(self) -> ElementTree.Element:
        """Returns an XML node representing the data of this instance.

        Returns:
            XML node containing the instance's data
        """
        pass


class VirtualAxisButton(AbstractVirtualButton):
    """Virtual button which turns an axis range into a button."""

    def __init__(self, lower_limit: float = -0.1, upper_limit: float = 0.1) -> None:
        """Creates a new instance.

        Args:
            lower_limit: the lower limit of the virtual button
            upper_limit: the upper limit of the virtual button
        """
        super().__init__()

        self.lower_limit = lower_limit
        self.upper_limit = upper_limit
        self.direction = AxisButtonDirection.Anywhere
