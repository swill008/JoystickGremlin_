# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import sys

sys.path.append(".")

from PySide6 import QtCore

from action_plugins.root import RootData
from gremlin.profile import InputItem, InputItemBinding, Profile
from gremlin.types import InputType
from gremlin.ui.profile import InputItemModel

_app = QtCore.QCoreApplication.instance() or QtCore.QCoreApplication([])


def _sequences():
    profile = Profile()
    item = InputItem(profile.library)
    item.input_type = InputType.JoystickButton
    item.input_id = 1
    roots = []
    for _ in range(3):
        binding = InputItemBinding(item)
        binding.root_action = RootData(InputType.JoystickButton)
        binding.behavior = InputType.JoystickButton
        item.action_sequences.append(binding)
        roots.append(binding.root_action.id)
    model = InputItemModel(item, 0, None)
    return model, roots


def test_drop_places_a_sequence_after_another() -> None:
    model, roots = _sequences()
    model.dropAction(str(roots[0]), str(roots[1]), "after")
    order = [entry.root_action.id for entry in model._input_item.action_sequences]
    assert order == [roots[1], roots[0], roots[2]]
    assert len(order) == 3


def test_drop_places_a_sequence_before_another() -> None:
    model, roots = _sequences()
    model.dropAction(str(roots[2]), str(roots[0]), "before")
    order = [entry.root_action.id for entry in model._input_item.action_sequences]
    assert order == [roots[2], roots[0], roots[1]]


def test_drop_on_itself_keeps_the_order() -> None:
    model, roots = _sequences()
    model.dropAction(str(roots[1]), str(roots[1]), "before")
    order = [entry.root_action.id for entry in model._input_item.action_sequences]
    assert order == roots
