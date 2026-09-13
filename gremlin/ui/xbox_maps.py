# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations


def walk_actions(action) -> list:
    found = [action]
    getter = getattr(action, "get_actions", None)
    if not callable(getter):
        return found
    try:
        buckets = getter()
    except Exception:
        return found
    if isinstance(buckets, (list, tuple)):
        for bucket in buckets:
            if isinstance(bucket, (list, tuple)):
                for child in bucket:
                    found.extend(walk_actions(child))
    return found


def xbox_maps_for_item(item) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    if item is None:
        return out
    for seq in getattr(item, "action_sequences", []) or []:
        root = getattr(seq, "root_action", None)
        if root is None:
            continue
        for action in walk_actions(root):
            if getattr(action, "tag", "") != "map-to-xbox":
                continue
            try:
                target = getattr(action, "xbox_target", None)
                value = target.value if hasattr(target, "value") else str(target)
                out.append((int(action.xbox_device_id), str(value)))
            except Exception:
                continue
    return out
