# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import json
import uuid
from pathlib import Path

from PySide6 import QtCore

import dill
import gremlin.ui.type_aliases as ta
from gremlin import (
    config,
    device_initialization,
    event_handler,
)
from gremlin.signal import signal
from gremlin.types import InputType, PropertyType
from gremlin.ui.hardware_profile import HardwareProfile, _maps_dir, _slug

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1

KEYBOARD_GUID = "6F1D2B61-D5A0-11CF-BFC7-444553540000"
OSC_GUID = "A7C3E91B-4D2F-4E18-9B06-2F8C1D5A6E70"
XBOX_GUID = "C8E4B6A1-3D92-4F17-9A50-7B2C4E8F1D60"
LOGICAL_GUID = "F0AF472F-8E17-493B-A1EB-7333EE8543F2"

_CFG_SECTION = "display"
_CFG_GROUP = "status"
_CFG_HIDDEN = "hidden-slugs"
_CFG_ORDER = "card-order"
_CFG_SHOW_STUBS = "show-stubs"


def _ensure_display_options() -> None:
    cfg = config.Configuration()
    if not cfg.exists(_CFG_SECTION, _CFG_GROUP, _CFG_HIDDEN):
        cfg.register(
            _CFG_SECTION,
            _CFG_GROUP,
            _CFG_HIDDEN,
            PropertyType.String,
            "",
            "Ignored Status card slugs (comma separated).",
            {},
            True,
        )
    if not cfg.exists(_CFG_SECTION, _CFG_GROUP, _CFG_SHOW_STUBS):
        cfg.register(
            _CFG_SECTION,
            _CFG_GROUP,
            _CFG_SHOW_STUBS,
            PropertyType.Bool,
            True,
            "Show stub cards for detected hardware with no saved module.",
            {},
            True,
        )
    if not cfg.exists(_CFG_SECTION, _CFG_GROUP, _CFG_ORDER):
        cfg.register(
            _CFG_SECTION,
            _CFG_GROUP,
            _CFG_ORDER,
            PropertyType.String,
            "",
            "Status card order (comma separated slugs).",
            {},
            True,
        )


def _hidden_slugs() -> set[str]:
    _ensure_display_options()
    raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_HIDDEN) or "")
    return {p.strip() for p in raw.split(",") if p.strip()}


def _set_hidden(slugs: set[str]) -> None:
    _ensure_display_options()
    config.Configuration().set(
        _CFG_SECTION, _CFG_GROUP, _CFG_HIDDEN, ",".join(sorted(slugs))
    )


def _norm_guid(value) -> str:
    text = str(value or "").upper()
    return text.replace("{", "").replace("}", "").replace("-", "")


def _order_slugs() -> list[str]:
    _ensure_display_options()
    raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_ORDER) or "")
    return [p.strip() for p in raw.split(",") if p.strip()]


def _set_order(slugs: list[str]) -> None:
    _ensure_display_options()
    config.Configuration().set(
        _CFG_SECTION, _CFG_GROUP, _CFG_ORDER, ",".join(slugs)
    )


def _show_stubs() -> bool:
    _ensure_display_options()
    return bool(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_SHOW_STUBS))


def _load_module_doc(device_name: str) -> dict:
    path = _maps_dir() / f"{_slug(device_name)}.json"
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def _claim_from_doc(doc: dict) -> dict:
    claim = doc.get("claim") if isinstance(doc.get("claim"), dict) else {}
    buttons: list[int] = list(claim.get("buttons") or [])
    axes: list[int] = list(claim.get("axes") or [])
    hats: list[int] = list(claim.get("hats") or [])
    friendly: dict[str, str] = dict(claim.get("friendly") or {})
    if not buttons and not axes and not hats:
        for node in doc.get("nodes") or []:
            if not isinstance(node, dict):
                continue
            kind = str(node.get("kind") or "")
            if kind == "btn" and node.get("hwId") is not None:
                buttons.append(int(node["hwId"]))
                if node.get("friendly"):
                    friendly[f"button:{int(node['hwId'])}"] = str(node["friendly"])
            elif kind == "axis" and node.get("hwId") is not None:
                axes.append(int(node["hwId"]))
            elif kind == "hat" and node.get("hwId") is not None:
                hats.append(int(node["hwId"]))
            elif kind in ("stack", "axis_stack"):
                for member in node.get("members") or []:
                    if not isinstance(member, dict) or member.get("hwId") is None:
                        continue
                    hid = int(member["hwId"])
                    buttons.append(hid)
                    if member.get("friendly"):
                        friendly[f"button:{hid}"] = str(member["friendly"])
    return {
        "buttons": sorted(set(buttons)),
        "axes": sorted(set(axes)),
        "hats": sorted(set(hats)),
        "friendly": friendly,
    }


def module_exists(device_name: str) -> bool:
    path = _maps_dir() / f"{_slug(device_name)}.json"
    return path.is_file()


class ModuleRow:
    __slots__ = (
        "slug",
        "name",
        "raw_name",
        "guid",
        "direction",
        "status",
        "bus",
        "buttons",
        "axes",
        "hats",
        "photo",
        "is_stub",
        "is_module",
        "tab",
        "target",
        "vid",
        "pid",
        "last_friendly",
        "last_hardware",
    )

    def __init__(self) -> None:
        self.slug = ""
        self.name = ""
        self.raw_name = ""
        self.guid = ""
        self.direction = "source"
        self.status = "Stub"
        self.bus = "DirectInput"
        self.buttons = 0
        self.axes = 0
        self.hats = 0
        self.photo = ""
        self.is_stub = True
        self.is_module = False
        self.tab = "physical"
        self.target = ""
        self.vid = ""
        self.pid = ""
        self.last_friendly = ""
        self.last_hardware = ""


@ta.QmlElement
class ModuleListModel(QtCore.QAbstractListModel):
    """Status cards: detected hardware stubs plus saved modules."""

    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"slug"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"name"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"rawName"),
        QtCore.Qt.ItemDataRole.UserRole + 4: QtCore.QByteArray(b"guid"),
        QtCore.Qt.ItemDataRole.UserRole + 5: QtCore.QByteArray(b"direction"),
        QtCore.Qt.ItemDataRole.UserRole + 6: QtCore.QByteArray(b"status"),
        QtCore.Qt.ItemDataRole.UserRole + 7: QtCore.QByteArray(b"bus"),
        QtCore.Qt.ItemDataRole.UserRole + 8: QtCore.QByteArray(b"buttons"),
        QtCore.Qt.ItemDataRole.UserRole + 9: QtCore.QByteArray(b"axes"),
        QtCore.Qt.ItemDataRole.UserRole + 10: QtCore.QByteArray(b"hats"),
        QtCore.Qt.ItemDataRole.UserRole + 11: QtCore.QByteArray(b"photo"),
        QtCore.Qt.ItemDataRole.UserRole + 12: QtCore.QByteArray(b"isStub"),
        QtCore.Qt.ItemDataRole.UserRole + 13: QtCore.QByteArray(b"isModule"),
        QtCore.Qt.ItemDataRole.UserRole + 14: QtCore.QByteArray(b"tab"),
        QtCore.Qt.ItemDataRole.UserRole + 15: QtCore.QByteArray(b"target"),
        QtCore.Qt.ItemDataRole.UserRole + 16: QtCore.QByteArray(b"vid"),
        QtCore.Qt.ItemDataRole.UserRole + 17: QtCore.QByteArray(b"pid"),
        QtCore.Qt.ItemDataRole.UserRole + 18: QtCore.QByteArray(b"lastLine"),
        QtCore.Qt.ItemDataRole.UserRole + 19: QtCore.QByteArray(b"lastHardware"),
        QtCore.Qt.ItemDataRole.UserRole + 20: QtCore.QByteArray(b"focused"),
    }

    modelResetNeeded = QtCore.Signal()
    lastChanged = QtCore.Signal()
    focusChanged = QtCore.Signal()
    hiddenChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._rows: list[ModuleRow] = []
        self._focus = ""
        self._last: dict[str, tuple[str, str]] = {}
        self._hw = HardwareProfile(self)
        _ensure_display_options()
        self._reload()
        event_handler.EventListener().device_change_event.connect(self._reload)
        event_handler.EventListener().joystick_event.connect(self._on_joy)
        signal.profileChanged.connect(self._reload)
        signal.configChanged.connect(self._reload)

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._rows)

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles

    def data(self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole):
        if role not in self.roles or not index.isValid():
            return None
        row = self._rows[index.row()]
        last_f, last_h = self._last.get(row.slug, (row.last_friendly, row.last_hardware))
        match bytes(self.roles[role]).decode():
            case "slug":
                return row.slug
            case "name":
                return row.name
            case "rawName":
                return row.raw_name
            case "guid":
                return row.guid
            case "direction":
                return row.direction
            case "status":
                return row.status
            case "bus":
                return row.bus
            case "buttons":
                return row.buttons
            case "axes":
                return row.axes
            case "hats":
                return row.hats
            case "photo":
                return row.photo
            case "isStub":
                return row.is_stub
            case "isModule":
                return row.is_module
            case "tab":
                return row.tab
            case "target":
                return row.target
            case "vid":
                return row.vid
            case "pid":
                return row.pid
            case "lastLine":
                return last_f
            case "lastHardware":
                return last_h
            case "focused":
                return row.slug == self._focus
            case _:
                return None

    @QtCore.Slot()
    def reload(self) -> None:
        self._reload()

    @QtCore.Slot(str)
    def setFocus(self, slug: str) -> None:
        if slug == self._focus:
            return
        self._focus = slug
        if self._rows:
            self.dataChanged.emit(
                self.index(0, 0),
                self.index(len(self._rows) - 1, 0),
                [QtCore.Qt.ItemDataRole.UserRole + 20],
            )
        self.focusChanged.emit()

    @QtCore.Property(str, notify=focusChanged)
    def focusedSlug(self) -> str:
        return self._focus

    @QtCore.Slot(str)
    def ignoreSlug(self, slug: str) -> None:
        hidden = _hidden_slugs()
        hidden.add(slug)
        _set_hidden(hidden)
        if self._focus == slug:
            self._focus = ""
        self._reload()
        self.hiddenChanged.emit()

    @QtCore.Slot(str)
    def unignoreSlug(self, slug: str) -> None:
        hidden = _hidden_slugs()
        hidden.discard(slug)
        _set_hidden(hidden)
        self._reload()
        self.hiddenChanged.emit()

    @QtCore.Slot(result=list)
    def hiddenList(self) -> list[str]:
        return sorted(_hidden_slugs())

    @QtCore.Slot(str, int)
    def moveSlug(self, slug: str, to_index: int) -> None:
        current = [row.slug for row in self._rows]
        if slug not in current:
            return
        current.remove(slug)
        dest = max(0, min(int(to_index), len(current)))
        current.insert(dest, slug)
        extras = [s for s in _order_slugs() if s not in current and s not in _hidden_slugs()]
        _set_order(current + extras)
        self._reload()

    @QtCore.Slot(result=int)
    def visibleCount(self) -> int:
        return len(self._rows)

    def _row_map(self, row: ModuleRow) -> dict:
        last_f, last_h = self._last.get(row.slug, (row.last_friendly, row.last_hardware))
        return {
            "slug": row.slug,
            "name": row.name,
            "rawName": row.raw_name,
            "guid": row.guid,
            "direction": row.direction,
            "status": row.status,
            "bus": row.bus,
            "buttons": row.buttons,
            "axes": row.axes,
            "hats": row.hats,
            "photo": row.photo,
            "isStub": row.is_stub,
            "isModule": row.is_module,
            "tab": row.tab,
            "target": row.target,
            "vid": row.vid,
            "pid": row.pid,
            "lastLine": last_f,
            "lastHardware": last_h,
            "focused": row.slug == self._focus,
        }

    @QtCore.Slot(str, result="QVariantMap")
    def cardMap(self, slug: str) -> dict:
        for row in self._rows:
            if row.slug == slug:
                return self._row_map(row)
        return {}

    @QtCore.Slot(result="QVariantMap")
    def focusedCardMap(self) -> dict:
        if self._focus:
            found = self.cardMap(self._focus)
            if found:
                return found
        if self._rows:
            return self._row_map(self._rows[0])
        return {}

    @QtCore.Slot(str, str, int, result=bool)
    def isClaimedInput(self, device_name: str, kind: str, hw_id: int) -> bool:
        doc = _load_module_doc(device_name)
        if not doc:
            return True
        claim = _claim_from_doc(doc)
        if not claim["buttons"] and not claim["axes"] and not claim["hats"]:
            return True
        if kind == "button":
            return int(hw_id) in claim["buttons"]
        if kind == "axis":
            return int(hw_id) in claim["axes"]
        if kind == "hat":
            return int(hw_id) in claim["hats"]
        return False

    def _on_joy(self, event: event_handler.Event) -> None:
        if event is None:
            return
        guid = _norm_guid(event.device_guid)
        row = next((r for r in self._rows if _norm_guid(r.guid) == guid), None)
        if row is None:
            return
        kind = "button"
        hid = int(getattr(event, "identifier", 0) or 0)
        et = getattr(event, "event_type", None)
        if et == InputType.JoystickAxis:
            kind = "axis"
        elif et == InputType.JoystickHat:
            kind = "hat"
        hardware = f"{kind} {hid}"
        doc = _load_module_doc(row.raw_name or row.name)
        claim = _claim_from_doc(doc) if doc else {"friendly": {}}
        friendly = claim.get("friendly", {}).get(f"{kind}:{hid}", "") or hardware.replace(
            "button", "Button"
        ).replace("axis", "Axis").replace("hat", "Hat")
        self._last[row.slug] = (friendly, hardware)
        idx = self._rows.index(row)
        self.dataChanged.emit(
            self.index(idx, 0),
            self.index(idx, 0),
            [QtCore.Qt.ItemDataRole.UserRole + 18, QtCore.Qt.ItemDataRole.UserRole + 19],
        )
        self.lastChanged.emit()

    def _reload(self) -> None:
        hidden = _hidden_slugs()
        show_stubs = _show_stubs()
        rows: list[ModuleRow] = []

        for dev in device_initialization.physical_devices():
            name = dev.name
            slug = _slug(name)
            if slug in hidden:
                continue
            saved = module_exists(name)
            if not saved and not show_stubs:
                continue
            row = ModuleRow()
            row.slug = slug
            row.raw_name = name
            row.name = name
            row.guid = str(dev.device_guid)
            row.direction = "source"
            row.tab = "physical"
            row.bus = "DirectInput"
            row.vid = f"{dev.vendor_id:04X}"
            row.pid = f"{dev.product_id:04X}"
            row.photo = self._hw.profilePhotoUrl(name)
            if saved:
                doc = _load_module_doc(name)
                claim = _claim_from_doc(doc)
                row.is_stub = False
                row.is_module = True
                row.status = "Connected"
                row.buttons = len(claim["buttons"]) or int(getattr(dev, "button_count", 0) or 0)
                row.axes = len(claim["axes"]) or int(getattr(dev, "axis_count", 0) or 0)
                row.hats = len(claim["hats"]) or int(getattr(dev, "hat_count", 0) or 0)
                if doc.get("device"):
                    row.name = str(doc.get("device"))
            else:
                row.is_stub = True
                row.is_module = False
                row.status = "Stub"
                row.buttons = int(getattr(dev, "button_count", 0) or 0)
                row.axes = int(getattr(dev, "axis_count", 0) or 0)
                row.hats = int(getattr(dev, "hat_count", 0) or 0)
            rows.append(row)

        def extra(slug: str, name: str, guid: str, tab: str, bus: str, direction: str) -> None:
            if slug in hidden:
                return
            saved = module_exists(name)
            if not saved and not show_stubs and direction == "source":
                return
            row = ModuleRow()
            row.slug = slug
            row.name = name
            row.raw_name = name
            row.guid = guid
            row.direction = direction
            row.tab = tab
            row.bus = bus
            row.is_module = saved
            row.is_stub = not saved
            row.status = "Virtual" if direction == "dest" else ("Connected" if saved else "Stub")
            row.photo = self._hw.profilePhotoUrl(name)
            if saved:
                claim = _claim_from_doc(_load_module_doc(name))
                row.buttons = len(claim["buttons"])
                row.axes = len(claim["axes"])
                row.hats = len(claim["hats"])
            rows.append(row)

        extra("keyboard", "Keyboard", KEYBOARD_GUID, "keyboard", "HID", "source")
        extra("osc", "OSC", OSC_GUID, "osc", "OSC", "source")

        for vdev in device_initialization.vjoy_devices():
            name = f"vJoy {vdev.vjoy_id}"
            slug = _slug(name)
            if slug in hidden:
                continue
            row = ModuleRow()
            row.slug = slug
            row.name = name
            row.raw_name = name
            row.guid = str(vdev.device_guid)
            row.direction = "dest"
            row.tab = "physical"
            row.bus = "DirectInput"
            row.status = "Virtual"
            row.is_stub = not module_exists(name)
            row.is_module = not row.is_stub
            row.photo = self._hw.profilePhotoUrl(name)
            if not row.photo:
                row.photo = self._hw.profilePhotoUrl("vJoy")
            if row.is_module:
                claim = _claim_from_doc(_load_module_doc(name))
                row.buttons = len(claim["buttons"]) or int(vdev.button_count)
                row.axes = len(claim["axes"]) or int(vdev.axis_count)
                row.hats = len(claim["hats"]) or int(vdev.hat_count)
            else:
                row.buttons = vdev.button_count
                row.axes = vdev.axis_count
                row.hats = vdev.hat_count
            rows.append(row)

        extra("xbox", "Xbox 360 Controller", XBOX_GUID, "xbox", "XInput", "dest")

        logical = Path(_maps_dir() / "logical_device.json")
        if logical.is_file() or module_exists("Logical Device"):
            extra("logical", "Logical Device", LOGICAL_GUID, "logical", "Logical", "source")

        if not self._focus and rows:
            src = next((r for r in rows if r.direction == "source" and r.status != "Stub"), None)
            if src is None:
                src = next((r for r in rows if r.direction == "source"), rows[0])
            self._focus = src.slug

        order = _order_slugs()
        if order:
            rank = {slug: index for index, slug in enumerate(order)}
            rows.sort(key=lambda row: rank.get(row.slug, 1000 + len(rank)))
        visible = [row.slug for row in rows]
        if visible and visible != order:
            _set_order(visible)

        self.beginResetModel()
        self._rows = rows
        self.endResetModel()
        self.focusChanged.emit()


@ta.QmlElement
class DriverInputModel(QtCore.QAbstractListModel):
    """Full hardware list for Configure module (press-to-check)."""

    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"kind"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"hwId"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"label"),
        QtCore.Qt.ItemDataRole.UserRole + 4: QtCore.QByteArray(b"claimed"),
        QtCore.Qt.ItemDataRole.UserRole + 5: QtCore.QByteArray(b"friendly"),
    }

    changed = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._guid = ""
        self._device_name = ""
        self._rows: list[dict] = []
        try:
            event_handler.EventListener().joystick_event.connect(self._on_joy)
        except Exception:
            pass

    def rowCount(self, parent: ta.ModelIndex = QtCore.QModelIndex()) -> int:
        return len(self._rows)

    def roleNames(self) -> dict[int, QtCore.QByteArray]:
        return self.roles

    def data(self, index: ta.ModelIndex, role: int = QtCore.Qt.ItemDataRole.DisplayRole):
        if role not in self.roles or not index.isValid():
            return None
        row = self._rows[index.row()]
        return row.get(bytes(self.roles[role]).decode())

    @QtCore.Slot(str, str)
    def loadDevice(self, guid: str, device_name: str) -> None:
        self._guid = guid or ""
        self._device_name = device_name or ""
        rows: list[dict] = []
        claim = _claim_from_doc(_load_module_doc(device_name)) if device_name else {
            "buttons": [],
            "axes": [],
            "hats": [],
            "friendly": {},
        }
        info = None
        if guid:
            try:
                info = dill.DILL.get_device_information_by_guid(dill.GUID.from_str(guid))
            except Exception:
                info = None
        if info is None and (
            "xbox" in (device_name or "").lower()
            or _norm_guid(guid) == _norm_guid(XBOX_GUID)
        ):
            self._load_xbox_dest(claim)
            return
        if info is not None:
            for i in range(info.axis_count):
                hid = info.axis_map[i].axis_index
                rows.append(
                    {
                        "kind": "axis",
                        "hwId": hid,
                        "label": f"Axis {hid}",
                        "claimed": hid in claim["axes"],
                        "friendly": claim["friendly"].get(f"axis:{hid}", ""),
                    }
                )
            for hid in range(1, info.button_count + 1):
                rows.append(
                    {
                        "kind": "button",
                        "hwId": hid,
                        "label": f"Button {hid}",
                        "claimed": hid in claim["buttons"],
                        "friendly": claim["friendly"].get(f"button:{hid}", ""),
                    }
                )
            for hid in range(1, info.hat_count + 1):
                rows.append(
                    {
                        "kind": "hat",
                        "hwId": hid,
                        "label": f"Hat {hid}",
                        "claimed": hid in claim["hats"],
                        "friendly": claim["friendly"].get(f"hat:{hid}", ""),
                    }
                )
        self.beginResetModel()
        self._rows = rows
        self.endResetModel()
        self.changed.emit()

    def _load_xbox_dest(self, claim: dict) -> None:
        labels = [
            ("button", 1, "A"),
            ("button", 2, "B"),
            ("button", 3, "X"),
            ("button", 4, "Y"),
            ("button", 5, "LB"),
            ("button", 6, "RB"),
            ("button", 7, "Back"),
            ("button", 8, "Start"),
            ("button", 9, "LS"),
            ("button", 10, "RS"),
            ("axis", 1, "Left stick X"),
            ("axis", 2, "Left stick Y"),
            ("axis", 3, "Right stick X"),
            ("axis", 4, "Right stick Y"),
            ("axis", 5, "LT"),
            ("axis", 6, "RT"),
            ("hat", 1, "D-pad"),
        ]
        rows = []
        buckets = {"button": "buttons", "axis": "axes", "hat": "hats"}
        for kind, hid, label in labels:
            key = f"{kind}:{hid}"
            rows.append(
                {
                    "kind": kind,
                    "hwId": hid,
                    "label": label,
                    "claimed": hid in claim.get(buckets[kind], []),
                    "friendly": claim.get("friendly", {}).get(key, ""),
                }
            )
        self.beginResetModel()
        self._rows = rows
        self.endResetModel()
        self.changed.emit()

    def _on_joy(self, event: event_handler.Event) -> None:
        if event is None or not self._guid:
            return
        if _norm_guid(event.device_guid) != _norm_guid(self._guid):
            return
        kind = "button"
        et = getattr(event, "event_type", None)
        if et == InputType.JoystickAxis:
            kind = "axis"
        elif et == InputType.JoystickHat:
            kind = "hat"
        try:
            hid = int(event.identifier)
        except Exception:
            return
        self.markPressed(kind, hid)

    @QtCore.Slot(int, bool)
    def setClaimed(self, index: int, claimed: bool) -> None:
        if not (0 <= index < len(self._rows)):
            return
        self._rows[index]["claimed"] = bool(claimed)
        ix = self.index(index, 0)
        self.dataChanged.emit(ix, ix, [QtCore.Qt.ItemDataRole.UserRole + 4])

    @QtCore.Slot(int, str)
    def setFriendly(self, index: int, name: str) -> None:
        if not (0 <= index < len(self._rows)):
            return
        self._rows[index]["friendly"] = name
        ix = self.index(index, 0)
        self.dataChanged.emit(ix, ix, [QtCore.Qt.ItemDataRole.UserRole + 5])

    @QtCore.Slot(str, int)
    def markPressed(self, kind: str, hw_id: int) -> None:
        for i, row in enumerate(self._rows):
            if row["kind"] == kind and int(row["hwId"]) == int(hw_id):
                if not row["claimed"]:
                    self.setClaimed(i, True)
                return

    @QtCore.Slot(str, str, result=bool)
    def saveClaim(self, device_name: str, direction: str) -> bool:
        name = device_name or self._device_name
        path = _maps_dir() / f"{_slug(name)}.json"
        doc: dict = {}
        if path.is_file():
            try:
                doc = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                doc = {}
        buttons = [int(r["hwId"]) for r in self._rows if r["kind"] == "button" and r["claimed"]]
        axes = [int(r["hwId"]) for r in self._rows if r["kind"] == "axis" and r["claimed"]]
        hats = [int(r["hwId"]) for r in self._rows if r["kind"] == "hat" and r["claimed"]]
        friendly = {}
        for r in self._rows:
            if r["claimed"] and r.get("friendly"):
                friendly[f"{r['kind']}:{int(r['hwId'])}"] = str(r["friendly"])
        doc["kind"] = "control.hardware"
        doc["device"] = name
        doc["direction"] = direction or "source"
        if self._guid:
            doc["boundName"] = name
            # GUID stays local-only; stored for this machine bind, not exported.
            doc["boundGuidLocal"] = self._guid
        doc["claim"] = {
            "buttons": buttons,
            "axes": axes,
            "hats": hats,
            "friendly": friendly,
        }
        doc.setdefault("space", "world")
        doc.setdefault("pageW", 32000)
        doc.setdefault("pageH", 18000)
        doc.setdefault("photoWell", 0.75)
        doc.setdefault("nodes", [])
        folder = _maps_dir() / _slug(name)
        if folder.is_dir():
            photos = sorted(p for p in folder.glob("photo.*") if p.is_file())
            if photos:
                doc["image"] = f"qml/maps/{_slug(name)}/{photos[-1].name}"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        signal.configChanged.emit()
        return True
