# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only
# Device-Configuration-Macro Change — binding catalog for Configuration.

from __future__ import annotations

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin import common, shared_state
from gremlin.signal import signal
from gremlin.types import InputType
from gremlin.ui.module_inputs import ModuleClaimedInputModel, _kind_to_type
from gremlin.ui.module_model import _claim_from_doc, _load_module_doc

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1

_WRAPPERS = {
    "root",
    "chain",
    "tempo",
    "condition",
    "double-tap",
    "smart-toggle",
    "description",
    "reference",
}

_TYPE_LABELS = {
    "map-to-vjoy": "Map to vJoy",
    "map-to-keyboard": "Map to keyboard",
    "map-to-mouse": "Map to mouse",
    "map-to-xbox": "Map to Xbox",
    "map-to-logical-device": "Map to logical device",
    "macro": "Macro",
    "change-mode": "Change mode",
    "load-profile": "Load profile",
    "text-to-speech": "Text to speech",
    "run-command": "Run command",
    "play-sound": "Play sound",
    "response-curve": "Response curve",
    "merge-axis": "Merge axis",
    "split-axis": "Split axis",
    "axis-delta": "Axis delta",
    "dual-axis-deadzone": "Dual axis deadzone",
    "hat-buttons": "Hat buttons",
    "pause-resume": "Pause / resume",
}

_NAMED_FILTERS = {
    "vjoy": {"map-to-vjoy"},
    "keyboard": {"map-to-keyboard"},
    "mouse": {"map-to-mouse"},
    "xbox": {"map-to-xbox"},
    "macro": {"macro"},
    "mode": {"change-mode"},
}


def _action_children(action) -> list:
    kids = getattr(action, "children", None)
    if kids:
        return list(kids)
    try:
        acts, _containers = action.get_actions()
        return list(acts or [])
    except Exception:
        return []


def _key_name(key) -> str:
    name = getattr(key, "name", None)
    if name:
        return str(name)
    return str(key)


def summarize_action(action) -> tuple[str, str]:
    """Return (type label, destination) for a leaf action."""
    tag = str(getattr(action, "tag", "") or "")
    label = _TYPE_LABELS.get(tag, getattr(action, "name", None) or tag or "Action")
    dest = ""
    if tag == "map-to-vjoy":
        vid = getattr(action, "vjoy_device_id", "?")
        itype = getattr(action, "vjoy_input_type", InputType.JoystickButton)
        iid = getattr(action, "vjoy_input_id", 1)
        try:
            iname = common.input_to_ui_string(itype, int(iid))
        except Exception:
            iname = str(iid)
        dest = f"vJoy {vid} · {iname}"
    elif tag == "map-to-keyboard":
        keys = getattr(action, "keys", None) or []
        dest = " + ".join(_key_name(k) for k in keys) if keys else "Keyboard"
    elif tag == "map-to-mouse":
        mode = getattr(action, "mode", None)
        button = getattr(action, "button", None)
        dest = str(getattr(button, "name", None) or button or mode or "Mouse")
    elif tag == "map-to-xbox":
        target = getattr(action, "xbox_target", None)
        dest = str(getattr(target, "value", None) or target or "Xbox")
    elif tag == "map-to-logical-device":
        dest = str(getattr(action, "action_label", None) or "Logical device")
    elif tag == "macro":
        al = str(getattr(action, "action_label", "") or "")
        dest = al if al and al != "Macro" else "Macro"
    elif tag == "change-mode":
        modes = getattr(action, "_target_modes", None) or []
        dest = ", ".join(str(m) for m in modes) if modes else "Mode"
    elif tag == "load-profile":
        dest = str(getattr(action, "profile_path", None) or getattr(action, "path", None) or "Profile")
    elif tag == "text-to-speech":
        dest = str(getattr(action, "text", None) or "Speech")[:40]
    elif tag == "run-command":
        dest = str(getattr(action, "command", None) or "Command")
    elif tag == "play-sound":
        dest = str(getattr(action, "sound_file", None) or getattr(action, "filename", None) or "Sound")
    else:
        dest = str(getattr(action, "action_label", None) or label)
    return label, dest


def collect_leaves(action) -> list[tuple[str, str, str]]:
    """Walk wrappers; return (tag, type label, dest) for leaves."""
    tag = str(getattr(action, "tag", "") or "")
    kids = _action_children(action)
    if tag in _WRAPPERS or (kids and tag in _WRAPPERS):
        out: list[tuple[str, str, str]] = []
        for child in kids:
            out.extend(collect_leaves(child))
        if out:
            return out
        if tag in _WRAPPERS:
            return []
    if kids and tag in ("chain", "tempo", "condition", "double-tap", "smart-toggle"):
        out = []
        for child in kids:
            out.extend(collect_leaves(child))
        return out or [(tag, _TYPE_LABELS.get(tag, tag), _TYPE_LABELS.get(tag, tag))]
    label, dest = summarize_action(action)
    return [(tag, label, dest)]


def assignment_summary(shown: list[tuple[str, str, str]]) -> tuple[str, str]:
    summary = ", ".join(dest for _t, _l, dest in shown)
    text = (
        f"{len(shown)} assignment"
        + ("s" if len(shown) != 1 else "")
        + " — "
        + summary
    )
    return text, summary


def leaves_for_item(item) -> list[tuple[str, str, str]]:
    out: list[tuple[str, str, str]] = []
    if item is None:
        return out
    for seq in getattr(item, "action_sequences", None) or []:
        root = getattr(seq, "root_action", None)
        if root is None:
            continue
        out.extend(collect_leaves(root))
    return out


@ta.QmlElement
class BindingCatalogModel(QtCore.QAbstractListModel):
    """Grouped binding rows for the Configuration catalog (Device-Configuration-Macro Change)."""

    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"rowKind"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"name"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"summary"),
        QtCore.Qt.ItemDataRole.UserRole + 4: QtCore.QByteArray(b"typeLabel"),
        QtCore.Qt.ItemDataRole.UserRole + 5: QtCore.QByteArray(b"destLabel"),
        QtCore.Qt.ItemDataRole.UserRole + 6: QtCore.QByteArray(b"kind"),
        QtCore.Qt.ItemDataRole.UserRole + 7: QtCore.QByteArray(b"hwId"),
        QtCore.Qt.ItemDataRole.UserRole + 8: QtCore.QByteArray(b"deviceIndex"),
        QtCore.Qt.ItemDataRole.UserRole + 9: QtCore.QByteArray(b"bindingCount"),
        QtCore.Qt.ItemDataRole.UserRole + 10: QtCore.QByteArray(b"indent"),
    }

    guidChanged = QtCore.Signal()
    deviceNameChanged = QtCore.Signal()
    countChanged = QtCore.Signal()
    filtersChanged = QtCore.Signal()
    controlChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._claimed = ModuleClaimedInputModel(self)
        self._type_filter = "all"
        self._dest_filter = "all"
        self._rows: list[dict] = []
        self._dest_choices: list[str] = ["All devices"]
        self._control_item = None
        self._control_vb = None
        signal.profileChanged.connect(self.reload)
        signal.configChanged.connect(self.reload)
        self._claimed.countChanged.connect(self.reload)

    def _get_guid(self) -> str:
        return self._claimed.guid

    def _set_guid(self, guid: str) -> None:
        self._claimed.guid = guid
        self.guidChanged.emit()

    def _get_device_name(self) -> str:
        return self._claimed.deviceName

    def _set_device_name(self, name: str) -> None:
        self._claimed.deviceName = name
        self.deviceNameChanged.emit()

    @QtCore.Slot(str)
    def setMode(self, mode: str) -> None:
        self._claimed.setMode(mode)
        self.reload()

    def _get_type_filter(self) -> str:
        return self._type_filter

    def _set_type_filter(self, value: str) -> None:
        text = str(value or "all")
        if text == self._type_filter:
            return
        self._type_filter = text
        self.reload()
        self.filtersChanged.emit()

    def _get_dest_filter(self) -> str:
        return self._dest_filter

    def _set_dest_filter(self, value: str) -> None:
        text = str(value or "all")
        if text == self._dest_filter:
            return
        self._dest_filter = text
        self.reload()
        self.filtersChanged.emit()

    def _leaf_ok(self, tag: str, dest: str) -> bool:
        tf = self._type_filter
        if tf == "unmapped":
            return False
        if tf != "all":
            allowed = _NAMED_FILTERS.get(tf)
            if allowed is not None:
                if tag not in allowed:
                    return False
            elif tf == "other":
                named = set()
                for s in _NAMED_FILTERS.values():
                    named |= s
                if tag in named:
                    return False
        if self._dest_filter not in ("all", "All devices", ""):
            if dest != self._dest_filter:
                return False
        return True

    @QtCore.Slot()
    def reload(self) -> None:
        self._rebuild()

    def _rebuild(self) -> None:
        self.beginResetModel()
        self._rows = []
        dests: list[str] = []
        mapped = 0
        unmapped: list[dict] = []
        n = self._claimed.rowCount()
        for i in range(n):
            kind = self._claimed.kindAt(i)
            hw = self._claimed.hwIdAt(i)
            name = self._claimed.nameAt(i)
            didx = self._claimed.deviceIndexAt(i)
            item = self._claimed._input_item(
                {"kind": kind, "hwId": hw, "deviceIndex": didx, "name": name}
            )
            leaves = leaves_for_item(item)
            for tag, _lab, dest in leaves:
                if dest and dest not in dests:
                    dests.append(dest)
            shown = [x for x in leaves if self._leaf_ok(x[0], x[2])]
            if self._type_filter == "unmapped":
                if leaves:
                    continue
                unmapped.append(
                    {
                        "rowKind": "unmapped",
                        "name": name,
                        "summary": "",
                        "typeLabel": "",
                        "destLabel": "Not bound",
                        "kind": kind,
                        "hwId": hw,
                        "deviceIndex": didx,
                        "bindingCount": 0,
                        "indent": 0,
                    }
                )
                continue
            if not leaves:
                if self._type_filter == "all" and self._dest_filter in (
                    "all",
                    "All devices",
                    "",
                ):
                    unmapped.append(
                        {
                            "rowKind": "unmapped",
                            "name": name,
                            "summary": "",
                            "typeLabel": "",
                            "destLabel": "Not bound",
                            "kind": kind,
                            "hwId": hw,
                            "deviceIndex": didx,
                            "bindingCount": 0,
                            "indent": 0,
                        }
                    )
                continue
            if not shown:
                continue
            summary, dests_text = assignment_summary(shown)
            self._rows.append(
                {
                    "rowKind": "group",
                    "name": name,
                    "summary": summary,
                    "typeLabel": "",
                    "destLabel": dests_text,
                    "kind": kind,
                    "hwId": hw,
                    "deviceIndex": didx,
                    "bindingCount": len(shown),
                    "indent": 0,
                }
            )
            mapped += 1
            for tag, lab, dest in shown:
                self._rows.append(
                    {
                        "rowKind": "leaf",
                        "name": name,
                        "summary": dest,
                        "typeLabel": lab,
                        "destLabel": dest,
                        "kind": kind,
                        "hwId": hw,
                        "deviceIndex": didx,
                        "bindingCount": 1,
                        "indent": 1,
                    }
                )
        if unmapped:
            self._rows.append(
                {
                    "rowKind": "unmapped-header",
                    "name": "Unmapped",
                    "summary": f"{len(unmapped)} controls — click to add",
                    "typeLabel": "",
                    "destLabel": "",
                    "kind": "",
                    "hwId": 0,
                    "deviceIndex": -1,
                    "bindingCount": len(unmapped),
                    "indent": 0,
                }
            )
            self._rows.extend(unmapped)
        self._dest_choices = ["All devices"] + dests
        self.endResetModel()
        self.countChanged.emit()
        self.filtersChanged.emit()

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._rows)

    def data(self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._rows)):
            return None
        row = self._rows[index.row()]
        key = bytes(self.roles.get(role, b"")).decode()
        return row.get(key)

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles

    @QtCore.Slot(int, result=int)
    def deviceIndexAt(self, row: int) -> int:
        if 0 <= row < len(self._rows):
            return int(self._rows[row]["deviceIndex"])
        return -1

    @QtCore.Slot(int, result=int)
    def leafRun(self, row: int) -> int:
        """How many child rows follow this parent."""
        if row < 0 or row >= len(self._rows):
            return 0
        if self._rows[row]["rowKind"] != "group":
            return 0
        count = 0
        i = row + 1
        while i < len(self._rows) and self._rows[i]["rowKind"] == "leaf":
            count += 1
            i += 1
        return count

    @QtCore.Slot(int, result=bool)
    def lastLeaf(self, row: int) -> bool:
        if row < 0 or row >= len(self._rows):
            return False
        if self._rows[row]["rowKind"] != "leaf":
            return False
        nxt = row + 1
        return nxt >= len(self._rows) or self._rows[nxt]["rowKind"] != "leaf"

    def _shown_for_device(self, device_index: int):
        want = int(device_index)
        n = self._claimed.rowCount()
        for i in range(n):
            if int(self._claimed.deviceIndexAt(i)) != want:
                continue
            kind = self._claimed.kindAt(i)
            hw = self._claimed.hwIdAt(i)
            name = self._claimed.nameAt(i)
            item = self._claimed._input_item(
                {"kind": kind, "hwId": hw, "deviceIndex": want, "name": name}
            )
            shown = [
                leaf for leaf in leaves_for_item(item) if self._leaf_ok(leaf[0], leaf[2])
            ]
            return name, kind, hw, want, shown
        return None

    def _emit_row(self, row: int) -> None:
        idx = self.index(row, 0)
        self.dataChanged.emit(idx, idx, list(self.roles.keys()))

    def _leaf_row(self, name, kind, hw, didx, lab, dest) -> dict:
        return {
            "rowKind": "leaf",
            "name": name,
            "summary": dest,
            "typeLabel": lab,
            "destLabel": dest,
            "kind": kind,
            "hwId": hw,
            "deviceIndex": didx,
            "bindingCount": 1,
            "indent": 1,
        }

    def _replace_leaves(self, row: int, name, kind, hw, didx, shown) -> None:
        existing = self.leafRun(row)
        fresh = [self._leaf_row(name, kind, hw, didx, lab, dest) for _tag, lab, dest in shown]
        if existing == len(fresh):
            for offset, leaf in enumerate(fresh):
                self._rows[row + 1 + offset] = leaf
            if existing:
                top = self.index(row + 1, 0)
                bottom = self.index(row + existing, 0)
                self.dataChanged.emit(top, bottom, list(self.roles.keys()))
            return
        if existing:
            self.beginRemoveRows(QtCore.QModelIndex(), row + 1, row + existing)
            del self._rows[row + 1 : row + 1 + existing]
            self.endRemoveRows()
        if fresh:
            self.beginInsertRows(QtCore.QModelIndex(), row + 1, row + len(fresh))
            self._rows[row + 1 : row + 1] = fresh
            self.endInsertRows()
        self.countChanged.emit()

    def _apply_summary(self, row: int, shown) -> None:
        text, summary = assignment_summary(shown)
        current = self._rows[row]
        if (
            current.get("summary") == text
            and int(current.get("bindingCount") or 0) == len(shown)
        ):
            return
        current["summary"] = text
        current["destLabel"] = summary
        current["bindingCount"] = len(shown)
        self._emit_row(row)

    @QtCore.Slot(int, result=bool)
    def noteOpenRow(self, device_index: int) -> bool:
        """Update the open parent summary. Do not insert or remove rows."""
        found = self._shown_for_device(device_index)
        if found is None:
            return False
        _name, _kind, _hw, didx, shown = found
        row = self.rowForDeviceIndex(didx)
        if row < 0:
            return False
        current = self._rows[row]
        if current["rowKind"] != "group" or not shown:
            return False
        self._apply_summary(row, shown)
        return False

    @QtCore.Slot(int, result=bool)
    def refreshOpenRow(self, device_index: int) -> bool:
        """Update one control without resetting the list.

        Returns True when the row had to move between mapped and unmapped,
        which rebuilds the list.
        """
        found = self._shown_for_device(device_index)
        if found is None:
            return False
        name, kind, hw, didx, shown = found
        row = self.rowForDeviceIndex(didx)
        if row < 0:
            self._rebuild()
            return True
        current = self._rows[row]
        kind_now = current["rowKind"]
        if kind_now == "unmapped" and not shown:
            return False
        if kind_now != "group" or not shown:
            self._rebuild()
            return True
        text, summary = assignment_summary(shown)
        same = (
            current.get("summary") == text
            and int(current.get("bindingCount") or 0) == len(shown)
            and self.leafRun(row) == len(shown)
        )
        if same:
            for offset, (_tag, lab, dest) in enumerate(shown):
                leaf = self._rows[row + 1 + offset]
                if leaf.get("typeLabel") != lab or leaf.get("destLabel") != dest:
                    same = False
                    break
        if same:
            return False
        current["summary"] = text
        current["destLabel"] = summary
        current["bindingCount"] = len(shown)
        self._emit_row(row)
        self._replace_leaves(row, name, kind, hw, didx, shown)
        return False

    @QtCore.Slot(int, result=int)
    def rowForDeviceIndex(self, device_index: int) -> int:
        want = int(device_index)
        fallback = -1
        for i, row in enumerate(self._rows):
            if int(row["deviceIndex"]) != want:
                continue
            if row["rowKind"] in ("group", "unmapped"):
                return i
            if fallback < 0:
                fallback = i
        return fallback

    @QtCore.Slot(int, result=bool)
    def addSequence(self, device_index: int) -> bool:
        """ADD on a catalog row: new action sequence for that control."""
        want = int(device_index)
        if want < 0:
            return False
        profile = shared_state.current_profile
        dev = getattr(self._claimed, "_device", None)
        if profile is None or dev is None:
            return False
        mode = str(getattr(self._claimed, "_mode", None) or "Default")
        n = self._claimed.rowCount()
        for i in range(n):
            if self._claimed.deviceIndexAt(i) != want:
                continue
            kind = self._claimed.kindAt(i)
            hw = self._claimed.hwIdAt(i)
            item = profile.get_input_item(
                dev.device_guid.uuid,
                _kind_to_type(kind),
                int(hw),
                mode,
                create_if_missing=True,
            )
            if item is None:
                return False
            item.add_item_binding()
            signal.inputItemChanged.emit(want)
            # Same UI refresh as InputItemModel.newActionSequence()
            signal.reloadCurrentInputItem.emit()
            return True
        return False

    def _lookup_control(self, device_index: int, create: bool):
        want = int(device_index)
        profile = shared_state.current_profile
        dev = getattr(self._claimed, "_device", None)
        if profile is None or dev is None or want < 0:
            return None, ""
        mode = str(getattr(self._claimed, "_mode", None) or "Default")
        n = self._claimed.rowCount()
        for i in range(n):
            if int(self._claimed.deviceIndexAt(i)) != want:
                continue
            kind = str(self._claimed.kindAt(i) or "")
            hw = int(self._claimed.hwIdAt(i))
            item = profile.get_input_item(
                dev.device_guid.uuid,
                _kind_to_type(kind),
                hw,
                mode,
                create_if_missing=create,
            )
            return item, kind
        return None, ""

    def _remember_virtual(self, item) -> None:
        from gremlin.ui.profile import VirtualButtonModel

        old = self._control_vb
        self._control_item = item
        self._control_vb = None
        if item is not None and getattr(item, "action_sequences", None):
            button = item.action_sequences[0].virtual_button
            if button is not None:
                model = VirtualButtonModel(button, self)
                model.lowerLimitChanged.connect(self._mirror_virtual)
                model.upperLimitChanged.connect(self._mirror_virtual)
                model.directionChanged.connect(self._mirror_virtual)
                model.hatDirectionChanged.connect(self._mirror_virtual)
                self._control_vb = model
        if old is not None and old is not self._control_vb:
            old.deleteLater()

    def _mirror_virtual(self) -> None:
        item = self._control_item
        sequences = getattr(item, "action_sequences", None) or []
        if len(sequences) < 2:
            return
        source = sequences[0].virtual_button
        if source is None:
            return
        for binding in sequences[1:]:
            other = binding.virtual_button
            if other is None or type(other) is not type(source):
                continue
            if hasattr(source, "lower_limit"):
                other.lower_limit = source.lower_limit
                other.upper_limit = source.upper_limit
                other.direction = source.direction
            if hasattr(source, "directions"):
                other.directions = list(source.directions)

    @QtCore.Slot(int, result=str)
    def controlBehavior(self, device_index: int) -> str:
        """How this control is treated. One value for the whole parent row."""
        from gremlin.types import InputType

        item, kind = self._lookup_control(device_index, False)
        if not kind:
            return "button"
        sequences = getattr(item, "action_sequences", None) or []
        if not sequences:
            return kind
        behavior = sequences[0].behavior
        if behavior == InputType.Keyboard:
            return "button"
        return InputType.to_string(behavior)

    @QtCore.Slot(int)
    def prepareControl(self, device_index: int) -> None:
        item, _kind = self._lookup_control(device_index, False)
        self._remember_virtual(item)
        self.controlChanged.emit()

    @QtCore.Slot(int, str)
    def setControlBehavior(self, device_index: int, behavior: str) -> None:
        """Set Treat as on every sequence of this control."""
        from gremlin.ui.profile import InputItemModel

        text = str(behavior or "").strip().lower()
        if text not in ("button", "axis", "hat"):
            return
        item, kind = self._lookup_control(device_index, True)
        if item is None:
            return
        if not item.action_sequences:
            if text == kind:
                self._remember_virtual(item)
                self.controlChanged.emit()
                return
            item.add_item_binding()
        want = int(device_index)
        host = InputItemModel(item, want, self)
        changed = False
        try:
            for row in range(host.rowCount()):
                model = host.data(host.index(row, 0))
                if model.behavior != text:
                    model.behavior = text
                    changed = True
            if changed:
                signal.inputItemChanged.emit(want)
                signal.reloadCurrentInputItem.emit()
        finally:
            host.deleteLater()
        self._remember_virtual(item)
        self.controlChanged.emit()

    @QtCore.Slot(int, result=QtCore.QObject)
    def controlVirtualButton(self, device_index: int):
        item, _kind = self._lookup_control(device_index, False)
        if item is not self._control_item:
            self._remember_virtual(item)
        return self._control_vb

    guid = QtCore.Property(str, fget=_get_guid, fset=_set_guid, notify=guidChanged)
    deviceName = QtCore.Property(
        str, fget=_get_device_name, fset=_set_device_name, notify=deviceNameChanged
    )
    typeFilter = QtCore.Property(
        str, fget=_get_type_filter, fset=_set_type_filter, notify=filtersChanged
    )
    destFilter = QtCore.Property(
        str, fget=_get_dest_filter, fset=_set_dest_filter, notify=filtersChanged
    )

    @QtCore.Property("QStringList", notify=filtersChanged)
    def destChoices(self) -> list[str]:
        return list(self._dest_choices)

    @QtCore.Property(int, notify=countChanged)
    def count(self) -> int:
        return len(self._rows)
