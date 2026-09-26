# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import sys
import uuid

sys.path.append(".")

from gremlin import shared_state
from gremlin.profile import Profile
from gremlin.types import InputType
from gremlin.ui.binding_catalog import (
    _attach_binding,
    _clone_binding,
    _drop_shadow,
    _fingerprint,
    _shadow_item,
)


def test_draft_does_not_change_the_parent_until_ok() -> None:
    profile = Profile()
    shared_state.current_profile = profile
    item = profile.get_input_item(
        uuid.uuid4(), InputType.JoystickButton, 1, "Default", True
    )
    item.add_item_binding()
    item.action_sequences[0].root_action.action_label = "keep"
    before = len(item.action_sequences)

    shadow = _shadow_item(item)
    _clone_binding(item.action_sequences[0], shadow)
    shadow.action_sequences[0].root_action.action_label = "draft"

    assert item.action_sequences[0].root_action.action_label == "keep"
    assert len(item.action_sequences) == before
    assert _fingerprint(shadow.action_sequences[0]) != _fingerprint(item.action_sequences[0])

    _drop_shadow(shadow)
    assert item.action_sequences[0].root_action.action_label == "keep"
    assert len(item.action_sequences) == before

    shadow = _shadow_item(item)
    shadow.add_item_binding()
    shadow.action_sequences[0].root_action.action_label = "new"
    index = _attach_binding(item, shadow, -1)

    assert index == 1
    assert item.action_sequences[0].root_action.action_label == "keep"
    assert item.action_sequences[1].root_action.action_label == "new"
