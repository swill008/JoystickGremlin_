# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only
# Device-Configuration-Macro Change — binding catalog for Configuration.

from __future__ import annotations

from xml.etree import ElementTree

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin import common, shared_state
from gremlin.plugin_manager import PluginManager
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
    "map-to-keyboard": "Map to Keyboard",
    "map-to-mouse": "Map to Mouse",
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


def leaves_for_item(item) -> list[tuple[int, str, str, str]]:
    """Return (seq_index, tag, type label, dest) for each leaf under the item."""
    out: list[tuple[int, str, str, str]] = []
    if item is None:
        return out
    for si, seq in enumerate(getattr(item, "action_sequences", None) or []):
        root = getattr(seq, "root_action", None)
        if root is None:
            continue
        leaves = collect_leaves(root)
        if not leaves:
            out.append((si, "", "New action", "Pick destination"))
            continue
        for tag, lab, dest in leaves:
            out.append((si, tag, lab, dest))
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
        QtCore.Qt.ItemDataRole.UserRole + 11: QtCore.QByteArray(b"seqIndex"),
    }

    guidChanged = QtCore.Signal()
    deviceNameChanged = QtCore.Signal()
    countChanged = QtCore.Signal()
    filtersChanged = QtCore.Signal()
    historyChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._claimed = ModuleClaimedInputModel(self)
        self._type_filter = "all"
        self._dest_filter = "all"
        self._rows: list[dict] = []
        self._dest_choices: list[str] = ["All devices"]
        self._undo: list[tuple[int, str]] = []
        self._redo: list[tuple[int, str]] = []
        self._last_xml: dict[int, str] = {}
        self._restoring = False
        signal.profileChanged.connect(self.reload)
        signal.inputItemChanged.connect(self.refreshHid)
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

    def _meta_at_claimed(self, i: int) -> dict:
        return {
            "kind": self._claimed.kindAt(i),
            "hwId": self._claimed.hwIdAt(i),
            "name": self._claimed.nameAt(i),
            "deviceIndex": self._claimed.deviceIndexAt(i),
        }

    def _meta_for_hid(self, hid: int) -> dict | None:
        want = int(hid)
        n = self._claimed.rowCount()
        for i in range(n):
            if self._claimed.deviceIndexAt(i) == want:
                return self._meta_at_claimed(i)
        return None

    def _blank_row(self, meta: dict, kind: str) -> dict:
        return {
            "rowKind": kind,
            "name": meta.get("name", ""),
            "summary": "",
            "typeLabel": "",
            "destLabel": "",
            "kind": meta.get("kind", ""),
            "hwId": meta.get("hwId", 0),
            "deviceIndex": meta.get("deviceIndex", -1),
            "bindingCount": 0,
            "indent": 0,
            "seqIndex": -1,
        }

    def _group_row(self, meta: dict, shown: list) -> dict:
        summary = ", ".join(dest for _si, _t, _l, dest in shown)
        row = self._blank_row(meta, "group")
        row["summary"] = (
            f"{len(shown)} assignment"
            + ("s" if len(shown) != 1 else "")
            + " — "
            + summary
        )
        row["destLabel"] = summary
        row["bindingCount"] = len(shown)
        return row

    def _leaf_row(self, meta: dict, si: int, lab: str, dest: str) -> dict:
        row = self._blank_row(meta, "leaf")
        row["summary"] = dest
        row["typeLabel"] = lab
        row["destLabel"] = dest
        row["bindingCount"] = 1
        row["indent"] = 1
        row["seqIndex"] = int(si)
        return row

    def _unmapped_row(self, meta: dict) -> dict:
        row = self._blank_row(meta, "unmapped")
        row["destLabel"] = "Not bound"
        return row

    def _build_rows(self, item, meta: dict) -> list[dict]:
        leaves = leaves_for_item(item)
        shown = [x for x in leaves if self._leaf_ok(x[1], x[3])]
        if self._type_filter == "unmapped":
            return [] if leaves else [self._unmapped_row(meta)]
        if not leaves:
            if self._type_filter == "all" and self._dest_filter in (
                "all",
                "All devices",
                "",
            ):
                return [self._unmapped_row(meta)]
            return []
        if not shown:
            return []
        return [self._group_row(meta, shown)] + [
            self._leaf_row(meta, si, lab, dest) for si, _tag, lab, dest in shown
        ]

    def _hid_span(self, hid: int) -> tuple[int, int]:
        start = -1
        end = -1
        want = int(hid)
        for i, row in enumerate(self._rows):
            if row["rowKind"] == "unmapped-header":
                if start >= 0:
                    break
                continue
            if int(row["deviceIndex"]) == want:
                if start < 0:
                    start = i
                end = i + 1
            elif start >= 0:
                break
        return start, end

    def _mapped_insert_at(self) -> int:
        for i, row in enumerate(self._rows):
            if row["rowKind"] == "unmapped-header":
                return i
        return len(self._rows)

    def _refresh_dest_choices(self) -> None:
        dests: list[str] = []
        for row in self._rows:
            if row["rowKind"] != "leaf":
                continue
            dest = str(row.get("destLabel") or "")
            if dest and dest not in dests:
                dests.append(dest)
        self._dest_choices = ["All devices"] + dests
        self.filtersChanged.emit()

    def _same_structure(self, old: list[dict], new: list[dict]) -> bool:
        if len(old) != len(new):
            return False
        for a, b in zip(old, new):
            if a["rowKind"] != b["rowKind"]:
                return False
            if int(a.get("seqIndex", -1)) != int(b.get("seqIndex", -1)):
                return False
        return True

    def _drop_empty_unmapped_header(self) -> None:
        header = -1
        kids = 0
        for i, row in enumerate(self._rows):
            if row["rowKind"] == "unmapped-header":
                header = i
            elif row["rowKind"] == "unmapped":
                kids += 1
        if header < 0:
            return
        if kids:
            row = dict(self._rows[header])
            row["bindingCount"] = kids
            row["summary"] = f"{kids} controls — click to add"
            self._rows[header] = row
            self.dataChanged.emit(self.index(header, 0), self.index(header, 0))
            return
        self.beginRemoveRows(QtCore.QModelIndex(), header, header)
        del self._rows[header]
        self.endRemoveRows()

    def _ensure_unmapped_header(self) -> int:
        for i, row in enumerate(self._rows):
            if row["rowKind"] == "unmapped-header":
                return i
        at = len(self._rows)
        header = {
            "rowKind": "unmapped-header",
            "name": "Unmapped",
            "summary": "0 controls — click to add",
            "typeLabel": "",
            "destLabel": "",
            "kind": "",
            "hwId": 0,
            "deviceIndex": -1,
            "bindingCount": 0,
            "indent": 0,
            "seqIndex": -1,
        }
        self.beginInsertRows(QtCore.QModelIndex(), at, at)
        self._rows.insert(at, header)
        self.endInsertRows()
        return at

    @QtCore.Slot(int)
    def refreshHid(self, device_index: int) -> None:
        """Update one control's catalog rows without resetting the list."""
        hid = int(device_index)
        if hid < 0:
            return
        meta = self._meta_for_hid(hid)
        if meta is None:
            return
        item = self._item_for_hid(hid)
        self._track_item(hid, item)
        new_rows = self._build_rows(item, meta)
        start, end = self._hid_span(hid)
        old = self._rows[start:end] if start >= 0 else []
        old_was_unmapped = bool(old) and old[0]["rowKind"] == "unmapped"
        if (
            start >= 0
            and old
            and new_rows
            and old[0]["rowKind"] == "group"
            and new_rows[0]["rowKind"] == "group"
            and len(new_rows) > len(old)
            and self._same_structure(old, new_rows[: len(old)])
        ):
            extra = new_rows[len(old) :]
            at = start + len(old)
            self.beginInsertRows(QtCore.QModelIndex(), at, at + len(extra) - 1)
            for i, row in enumerate(extra):
                self._rows.insert(at + i, row)
            self.endInsertRows()
            self._rows[start] = new_rows[0]
            self.dataChanged.emit(self.index(start, 0), self.index(start, 0))
            self.countChanged.emit()
            self._refresh_dest_choices()
            return
        if start >= 0 and self._same_structure(old, new_rows):
            for i, row in enumerate(new_rows):
                self._rows[start + i] = row
            if new_rows:
                self.dataChanged.emit(
                    self.index(start, 0),
                    self.index(start + len(new_rows) - 1, 0),
                )
            self._refresh_dest_choices()
            return
        if start >= 0 and end > start:
            self.beginRemoveRows(QtCore.QModelIndex(), start, end - 1)
            del self._rows[start:end]
            self.endRemoveRows()
        if not new_rows:
            self._drop_empty_unmapped_header()
            self.countChanged.emit()
            self._refresh_dest_choices()
            return
        new_is_unmapped = new_rows[0]["rowKind"] == "unmapped"
        if new_is_unmapped:
            header = self._ensure_unmapped_header()
            at = len(self._rows)
            if at <= header:
                at = header + 1
        elif old_was_unmapped or start < 0:
            at = self._mapped_insert_at()
        else:
            at = start
        last = at + len(new_rows) - 1
        self.beginInsertRows(QtCore.QModelIndex(), at, last)
        for i, row in enumerate(new_rows):
            self._rows.insert(at + i, row)
        self.endInsertRows()
        self._drop_empty_unmapped_header()
        self.countChanged.emit()
        self._refresh_dest_choices()

    @QtCore.Slot()
    def reload(self) -> None:
        self.beginResetModel()
        self._rows = []
        mapped: list[dict] = []
        unmapped: list[dict] = []
        n = self._claimed.rowCount()
        for i in range(n):
            meta = self._meta_at_claimed(i)
            item = self._claimed._input_item(
                {
                    "kind": meta["kind"],
                    "hwId": meta["hwId"],
                    "deviceIndex": meta["deviceIndex"],
                    "name": meta["name"],
                }
            )
            built = self._build_rows(item, meta)
            for row in built:
                if row["rowKind"] == "unmapped":
                    unmapped.append(row)
                else:
                    mapped.append(row)
        self._rows.extend(mapped)
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
                    "seqIndex": -1,
                }
            )
            self._rows.extend(unmapped)
        self.endResetModel()
        self.countChanged.emit()
        self._refresh_dest_choices()

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

    def _item_for_hid(self, device_index: int):
        want = int(device_index)
        if want < 0:
            return None
        profile = shared_state.current_profile
        dev = getattr(self._claimed, "_device", None)
        if profile is None or dev is None:
            return None
        mode = str(getattr(self._claimed, "_mode", None) or "Default")
        n = self._claimed.rowCount()
        for i in range(n):
            if self._claimed.deviceIndexAt(i) != want:
                continue
            kind = self._claimed.kindAt(i)
            hw = self._claimed.hwIdAt(i)
            return profile.get_input_item(
                dev.device_guid.uuid,
                _kind_to_type(kind),
                int(hw),
                mode,
                create_if_missing=True,
            )
        return None

    @QtCore.Slot(int, result="QStringList")
    def actionNames(self, device_index: int) -> list[str]:
        """Action types that can be added to this control (no Root)."""
        item = self._item_for_hid(device_index)
        itype = getattr(item, "input_type", None) if item is not None else None
        if itype is None:
            itype = InputType.JoystickButton
        try:
            plugins = PluginManager().type_action_map.get(itype, [])
        except Exception:
            plugins = []
        names = [entry.name for entry in plugins if getattr(entry, "tag", "") != "root"]
        lead = [
            "Map to vJoy",
            "Map to Keyboard",
            "Map to Mouse",
            "Map to Xbox",
            "Macro",
            "Change Mode",
        ]
        head = [n for n in lead if n in names]
        tail = [n for n in names if n not in head]
        return head + tail

    @QtCore.Slot(int, str, result=int)
    def addAction(self, device_index: int, action_name: str) -> int:
        """ADD + pick type: new sequence with that action under the button."""
        item = self._item_for_hid(device_index)
        if item is None:
            return -1
        binding = item.add_item_binding()
        name = str(action_name or "").strip()
        seq = len(item.action_sequences) - 1
        if name and binding is not None and binding.root_action is not None:
            try:
                action = PluginManager().create_instance(name, item.input_type)
            except Exception:
                action = None
            if action is not None:
                binding.root_action.insert_action(action, "children")
        signal.inputItemChanged.emit(int(device_index))
        signal.reloadCurrentInputItem.emit()
        return seq

    @QtCore.Slot(int, int, result=bool)
    def removeSequence(self, device_index: int, seq_index: int) -> bool:
        item = self._item_for_hid(device_index)
        if item is None:
            return False
        seqs = getattr(item, "action_sequences", None) or []
        if not (0 <= int(seq_index) < len(seqs)):
            return False
        item.remove_item_binding(seqs[int(seq_index)])
        signal.inputItemChanged.emit(int(device_index))
        signal.reloadCurrentInputItem.emit()
        return True


    def _xml_of(self, item) -> str:
        if item is None:
            return ""
        try:
            return ElementTree.tostring(item.to_xml(), encoding="unicode")
        except Exception:
            return ""

    def _track_item(self, hid: int, item) -> None:
        xml = self._xml_of(item)
        if not xml:
            return
        prev = self._last_xml.get(hid)
        self._last_xml[hid] = xml
        if prev is None or prev == xml or self._restoring:
            return
        self._undo.append((hid, prev))
        if len(self._undo) > 80:
            self._undo = self._undo[-80:]
        self._redo.clear()
        self.historyChanged.emit()

    def _apply_xml(self, hid: int, xml: str) -> None:
        from gremlin.profile import InputItemBinding

        item = self._item_for_hid(hid)
        if item is None:
            return
        self._restoring = True
        try:
            node = ElementTree.fromstring(xml)
            item.action_sequences.clear()
            for entry in node.findall("action-configuration"):
                binding = InputItemBinding(item)
                binding.from_xml(entry)
                item.action_sequences.append(binding)
            self._last_xml[hid] = xml
            signal.inputItemChanged.emit(int(hid))
            signal.reloadCurrentInputItem.emit()
        except Exception:
            pass
        finally:
            self._restoring = False
        self.historyChanged.emit()

    @QtCore.Slot(result=bool)
    def undo(self) -> bool:
        if not self._undo:
            return False
        hid, xml = self._undo.pop()
        item = self._item_for_hid(hid)
        current = self._xml_of(item)
        if current:
            self._redo.append((hid, current))
        self._apply_xml(hid, xml)
        return True

    @QtCore.Slot(result=bool)
    def redo(self) -> bool:
        if not self._redo:
            return False
        hid, xml = self._redo.pop()
        item = self._item_for_hid(hid)
        current = self._xml_of(item)
        if current:
            self._undo.append((hid, current))
        self._apply_xml(hid, xml)
        return True

    def _can_undo(self) -> bool:
        return bool(self._undo)

    def _can_redo(self) -> bool:
        return bool(self._redo)

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

    canUndo = QtCore.Property(bool, fget=_can_undo, notify=historyChanged)
    canRedo = QtCore.Property(bool, fget=_can_redo, notify=historyChanged)
