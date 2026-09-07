# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from xml.etree import ElementTree

from gremlin.profile import InputItem

_orig_init = InputItem.__init__
_orig_from_xml = InputItem.from_xml
_orig_to_xml = InputItem.to_xml


def _init(self, library) -> None:
    _orig_init(self, library)
    self.action_name = ""


def _from_xml(self, node: ElementTree.Element) -> None:
    _orig_from_xml(self, node)
    child = node.find("action-name")
    self.action_name = "" if child is None or child.text is None else child.text


def _to_xml(self) -> ElementTree.Element:
    node = _orig_to_xml(self)
    name = getattr(self, "action_name", "") or ""
    if name:
        child = ElementTree.SubElement(node, "action-name")
        child.text = name
    return node


InputItem.__init__ = _init
InputItem.from_xml = _from_xml
InputItem.to_xml = _to_xml
