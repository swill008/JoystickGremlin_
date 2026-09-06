# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only
"""Profile XML persistence and DILL guards for the virtual OSC device."""

from __future__ import annotations

from pathlib import Path
from xml.dom import minidom
from xml.etree import ElementTree

from PySide6 import QtCore

from gremlin.osc import OSC_DEVICE_UUID, OscDevice
from gremlin.profile import Profile
from gremlin.types import InputType
from gremlin.ui.device import InputIdentifier
from gremlin.util import create_subelement_node, read_subelement

_orig_init = Profile.__init__
_orig_from_xml = Profile.from_xml
_orig_to_xml = Profile.to_xml
_orig_label = InputIdentifier.label.fget
_orig_linear_index = InputIdentifier.linear_index.fget


def _osc_node() -> ElementTree.Element:
    node = ElementTree.Element("osc-device")
    for label in OscDevice().labels_of_type():
        item = OscDevice()[label]
        entry = ElementTree.Element("input")
        entry.append(create_subelement_node("input-type", item.type))
        entry.append(create_subelement_node("input-id", item.id))
        entry.append(create_subelement_node("label", item.label))
        node.append(entry)
    return node


def _load_osc_node(root: ElementTree.Element) -> None:
    osc = OscDevice()
    osc.reset()
    for node in root.findall("./osc-device/input"):
        osc.create(
            read_subelement(node, "input-type"),
            label=read_subelement(node, "label"),
            input_id=read_subelement(node, "input-id"),
        )


def _init(self) -> None:
    _orig_init(self)
    OscDevice().reset()


def _from_xml(self, fpath: Path) -> None:
    _orig_from_xml(self, fpath)
    _load_osc_node(ElementTree.parse(str(fpath)).getroot())


def _to_xml(self, fpath: Path) -> None:
    _orig_to_xml(self, fpath)
    tree = ElementTree.parse(str(fpath))
    root = tree.getroot()
    for old in list(root.findall("osc-device")):
        root.remove(old)
    node = _osc_node()
    logical = root.find("logical-device")
    children = list(root)
    if logical is not None:
        root.insert(children.index(logical) + 1, node)
    else:
        root.append(node)
    pretty = minidom.parseString(
        ElementTree.tostring(root, encoding="utf-8")
    ).toprettyxml(indent="    ")
    lines = [line for line in pretty.splitlines() if line.strip()]
    Path(fpath).write_text("\n".join(lines) + "\n", encoding="utf-8-sig")


def _label(self) -> str:
    if getattr(self, "isValid", False) and self.device_guid == OSC_DEVICE_UUID:
        item = OscDevice().find_by_id(self.input_type, int(self.input_id))
        if item is not None:
            return f"OSC - {item.label}"
        return (
            f"OSC - {InputType.to_string(self.input_type).capitalize()} "
            f"{self.input_id}"
        )
    return _orig_label(self)


def _linear_index(self) -> int:
    if getattr(self, "isValid", False) and self.device_guid == OSC_DEVICE_UUID:
        return max(int(self.input_id) - 1, 0)
    return _orig_linear_index(self)


Profile.__init__ = _init
Profile.from_xml = _from_xml
Profile.to_xml = _to_xml
InputIdentifier.label = QtCore.Property(
    str, _label, notify=InputIdentifier.changed
)
InputIdentifier.linear_index = property(_linear_index)
