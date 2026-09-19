# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from gremlin.config import Configuration
from gremlin.types import PropertyType

SECTION_DISPLAY = "display"
SECTION_CONTROL = "control-display"
SECTION_AUTOMAP = "automap"


def ensure_shell_options() -> None:
    cfg = Configuration()
    specs = [
        (
            SECTION_DISPLAY,
            "status",
            "show-stubs",
            PropertyType.Bool,
            True,
            "Show stub cards for detected hardware that has no saved module.",
        ),
        (
            SECTION_DISPLAY,
            "status",
            "last-keep-after-release",
            PropertyType.Bool,
            True,
            "Keep the last: value after the control is released.",
        ),
        (
            SECTION_CONTROL,
            "overlay",
            "hover-peek",
            PropertyType.Bool,
            True,
            "Hover peek Control Display on the Status card photo.",
        ),
        (
            SECTION_CONTROL,
            "overlay",
            "one-pin",
            PropertyType.Bool,
            True,
            "Only one pinned Control Display overlay on Status at a time.",
        ),
        (
            SECTION_AUTOMAP,
            "mapper",
            "remember-overwrite",
            PropertyType.Bool,
            True,
            "Remember the Auto Mapper overwrite-used-inputs checkbox.",
        ),
        (
            SECTION_AUTOMAP,
            "mapper",
            "overwrite-used-inputs",
            PropertyType.Bool,
            False,
            "Last Auto Mapper overwrite-used-inputs value.",
        ),
    ]
    for section, group, name, dtype, initial, desc in specs:
        if not cfg.exists(section, group, name):
            cfg.register(section, group, name, dtype, initial, desc, {}, True)
        else:
            cfg.register(
                section,
                group,
                name,
                dtype,
                cfg.value(section, group, name),
                desc,
                {},
                True,
            )


ensure_shell_options()
