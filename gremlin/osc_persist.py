# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only
"""DILL guards for the virtual OSC device.

OSC input rows are saved and loaded by Profile.to_xml / from_xml.
This module only keeps InputIdentifier off DILL for the OSC GUID.
"""

from __future__ import annotations

from PySide6 import QtCore

from gremlin.osc import OSC_DEVICE_UUID, OscDevice
from gremlin.types import InputType
from gremlin.ui.device import InputIdentifier

_orig_label = getattr(InputIdentifier.label, "fget", None)
_orig_linear_index = getattr(InputIdentifier.linear_index, "fget", None)


def _label(self) -> str:
    if getattr(self, "isValid", False) and self.device_guid == OSC_DEVICE_UUID:
        item = OscDevice().find_by_id(self.input_type, int(self.input_id))
        if item is not None:
            return f"OSC - {item.label}"
        return (
            f"OSC - {InputType.to_string(self.input_type).capitalize()} "
            f"{self.input_id}"
        )
    if _orig_label is not None:
        return _orig_label(self)
    return "No input"


def _linear_index(self) -> int:
    if getattr(self, "isValid", False) and self.device_guid == OSC_DEVICE_UUID:
        return max(int(self.input_id) - 1, 0)
    if _orig_linear_index is not None:
        return _orig_linear_index(self)
    return max(int(getattr(self, "input_id", 1) or 1) - 1, 0)


if _orig_label is not None:
    InputIdentifier.label = QtCore.Property(
        str, _label, notify=InputIdentifier.changed
    )
if _orig_linear_index is not None:
    InputIdentifier.linear_index = property(_linear_index)
