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
from gremlin import keyboard as gremlin_keyboard
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
_CFG_SPLIT = "split-mode"
_CFG_SPLIT_RATIO = "split-ratio"
_CFG_STACKS = "card-stacks"
_CFG_SIZES = "card-sizes"


def _ensure_display_options() -> None:
    cfg = config.Configuration()

    def _reg(name, dtype, initial, desc, props=None) -> None:
        try:
            cfg.register(
                _CFG_SECTION,
                _CFG_GROUP,
                name,
                dtype,
                initial,
                desc,
                props or {},
                True,
            )
        except Exception as exc:
            import logging
            logging.getLogger("system").warning("status option %s: %s", name, exc)

    _reg(_CFG_HIDDEN, PropertyType.String, "", "Ignored Status card slugs (comma separated).")
    _reg(
        _CFG_SHOW_STUBS,
        PropertyType.Bool,
        True,
        "Show stub cards for detected hardware with no saved module.",
    )
    _reg(_CFG_ORDER, PropertyType.String, "", "Status card order (comma separated slugs).")
    _reg(
        _CFG_SPLIT,
        PropertyType.String,
        "none",
        "Status split: none, vertical, or horizontal.",
    )
    _reg(
        _CFG_SPLIT_RATIO,
        PropertyType.Float,
        0.5,
        "Status splitter position (0.2–0.8).",
        {"min": 0.2, "max": 0.8},
    )
    _reg(_CFG_STACKS, PropertyType.String, "", "Status card stacks (slug+slug|slug).")
    _reg(_CFG_SIZES, PropertyType.String, "", "Status card sizes (slug=WxH).")


def _write_status(name: str, value) -> None:
    _ensure_display_options()
    try:
        config.Configuration().set(_CFG_SECTION, _CFG_GROUP, name, value)
    except Exception as exc:
        import logging
        logging.getLogger("system").warning("status save %s: %s", name, exc)


def _hidden_slugs() -> set[str]:
    _ensure_display_options()
    raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_HIDDEN) or "")
    return {p.strip() for p in raw.split(",") if p.strip()}


def _set_hidden(slugs: set[str]) -> None:
    _ensure_display_options()
    _write_status(_CFG_HIDDEN, ",".join(sorted(slugs)))


def _norm_guid(value) -> str:
    text = str(value or "").upper()
    return text.replace("{", "").replace("}", "").replace("-", "")


def _order_slugs() -> list[str]:
    _ensure_display_options()
    raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_ORDER) or "")
    return [p.strip() for p in raw.split(",") if p.strip()]


def _set_order(slugs: list[str]) -> None:
    _ensure_display_options()
    _write_status(_CFG_ORDER, ",".join(slugs))


def _sizes() -> dict[str, tuple[int, int]]:
    _ensure_display_options()
    raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_SIZES) or "")
    out: dict[str, tuple[int, int]] = {}
    for part in raw.split(","):
        part = part.strip()
        if "=" not in part or "x" not in part:
            continue
        slug, dim = part.split("=", 1)
        try:
            w_s, h_s = dim.lower().split("x", 1)
            w, h = int(w_s), int(h_s)
        except ValueError:
            continue
        if slug.strip() and w > 0 and h > 0:
            out[slug.strip()] = (w, h)
    return out


def _set_sizes(sizes: dict[str, tuple[int, int]]) -> None:
    packed = ",".join(f"{slug}={w}x{h}" for slug, (w, h) in sizes.items())
    _write_status(_CFG_SIZES, packed)


def _clamp_size(w: int, h: int) -> tuple[int, int]:
    return (
        max(220, min(720, int(w))),
        max(140, min(520, int(h))),
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
        "keys": [int(k) for k in (claim.get("keys") or [])],
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
    panesChanged = QtCore.Signal()
    claimsChanged = QtCore.Signal()

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

    @QtCore.Slot(str, str)
    def moveSlugBefore(self, slug: str, before_slug: str) -> None:
        groups = {g[0]: g for g in self._stacks()}
        stacked = {s for g in groups.values() for s in g}
        leaders: list[str] = []
        for row in self._rows:
            if row.slug in stacked and row.slug not in groups:
                continue
            leaders.append(row.slug)
        if slug not in leaders:
            leaders.append(slug)
        leaders = [s for s in leaders if s != slug]
        if before_slug and before_slug in leaders:
            leaders.insert(leaders.index(before_slug), slug)
        else:
            leaders.append(slug)
        expanded: list[str] = []
        for lead in leaders:
            expanded.extend(groups.get(lead, [lead]))
        extras = [s for s in _order_slugs() if s not in expanded and s not in _hidden_slugs()]
        _set_order(expanded + extras)
        self._reload()
        self.panesChanged.emit()

    @QtCore.Slot(result=int)
    def visibleCount(self) -> int:
        return len(self._rows)

    def _stacks(self) -> list[list[str]]:
        _ensure_display_options()
        raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_STACKS) or "")
        groups: list[list[str]] = []
        visible = {row.slug for row in self._rows}
        for part in raw.split("|"):
            group = [s.strip() for s in part.split("+") if s.strip() and s.strip() in visible]
            if len(group) > 1:
                groups.append(group)
        return groups

    def _set_stacks(self, groups: list[list[str]]) -> None:
        _ensure_display_options()
        packed = "|".join("+".join(g) for g in groups if len(g) > 1)
        _write_status(_CFG_STACKS, packed)

    @QtCore.Property(str, notify=panesChanged)
    def splitMode(self) -> str:
        try:
            _ensure_display_options()
            raw = str(
                config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_SPLIT) or "none"
            ).lower()
        except Exception:
            return "none"
        return raw if raw in ("none", "vertical", "horizontal") else "none"

    @QtCore.Slot(str)
    def setSplitMode(self, mode: str) -> None:
        name = (mode or "none").lower()
        if name not in ("none", "vertical", "horizontal"):
            name = "none"
        if name == self.splitMode:
            return
        try:
            _ensure_display_options()
            _write_status(_CFG_SPLIT, name)
        except Exception:
            return
        self.panesChanged.emit()

    @QtCore.Property(float, notify=panesChanged)
    def splitRatio(self) -> float:
        try:
            _ensure_display_options()
            raw = float(
                config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_SPLIT_RATIO) or 0.5
            )
        except Exception:
            return 0.5
        return min(0.8, max(0.2, raw))

    @QtCore.Slot(float)
    def setSplitRatio(self, ratio: float) -> None:
        value = min(0.8, max(0.2, float(ratio)))
        try:
            _ensure_display_options()
            _write_status(_CFG_SPLIT_RATIO, value)
        except Exception:
            return
        self.panesChanged.emit()

    @QtCore.Slot(str, result=list)
    def pileLeaders(self, direction: str) -> list:
        groups = {g[0]: g for g in self._stacks()}
        stacked = {s for g in groups.values() for s in g}
        leaders: list[str] = []
        for row in self._rows:
            if direction and row.direction != direction:
                continue
            if row.slug in stacked and row.slug not in groups:
                continue
            leaders.append(row.slug)
        return leaders

    @QtCore.Slot(str, result=list)
    def pileMembers(self, leader: str) -> list:
        for group in self._stacks():
            if leader in group:
                return group
        return [leader] if leader else []

    @QtCore.Slot(str, result=int)
    def cardWidth(self, slug: str) -> int:
        return int(_sizes().get(slug, (0, 0))[0])

    @QtCore.Slot(str, result=int)
    def cardHeight(self, slug: str) -> int:
        return int(_sizes().get(slug, (0, 0))[1])

    @QtCore.Slot(str, int, int)
    def setPileSize(self, slug: str, width: int, height: int) -> None:
        w, h = _clamp_size(width, height)
        sizes = _sizes()
        for member in self.pileMembers(slug):
            sizes[member] = (w, h)
        _set_sizes(sizes)
        self.panesChanged.emit()

    @QtCore.Slot(str)
    def resetCardSize(self, slug: str) -> None:
        sizes = _sizes()
        for member in self.pileMembers(slug):
            sizes.pop(member, None)
        _set_sizes(sizes)
        signal.configChanged.emit()
        self.panesChanged.emit()

    @QtCore.Slot(str)
    def clearCardSettings(self, slug: str) -> None:
        sizes = _sizes()
        sizes.pop(slug, None)
        _set_sizes(sizes)
        self.unstackSlug(slug)
        signal.configChanged.emit()
        self.panesChanged.emit()

    @QtCore.Slot()
    def resetAllCardSizes(self) -> None:
        _set_sizes({})
        signal.configChanged.emit()
        self.panesChanged.emit()

    @QtCore.Slot(str, str)
    def stackSlugs(self, src: str, dst: str) -> None:
        if not src or not dst or src == dst:
            return
        dirs = {row.slug: row.direction for row in self._rows}
        if dirs.get(src) and dirs.get(dst) and dirs[src] != dirs[dst]:
            return
        groups = self._stacks()
        src_group = next((g for g in groups if src in g), [src])
        dst_group = next((g for g in groups if dst in g), [dst])
        groups = [g for g in groups if src not in g and dst not in g]
        merged = [s for s in dst_group if s != src] + [s for s in src_group if s not in dst_group]
        if src not in merged:
            merged.append(src)
        groups.append(merged)
        self._set_stacks(groups)
        sizes = _sizes()
        shared = sizes.get(dst) or sizes.get(src)
        if shared:
            for member in merged:
                sizes[member] = shared
            _set_sizes(sizes)
        self._reload()
        self.panesChanged.emit()

    @QtCore.Slot(str)
    def unstackSlug(self, slug: str) -> None:
        groups = []
        changed = False
        for group in self._stacks():
            if slug in group:
                rest = [s for s in group if s != slug]
                if len(rest) > 1:
                    groups.append(rest)
                changed = True
            else:
                groups.append(group)
        if changed:
            self._set_stacks(groups)
            self._reload()
            self.panesChanged.emit()

    @QtCore.Slot(str)
    def unstackAll(self, slug: str) -> None:
        groups = []
        changed = False
        for group in self._stacks():
            if slug in group:
                changed = True
                continue
            groups.append(group)
        if changed:
            self._set_stacks(groups)
            self._reload()
            self.panesChanged.emit()

    @QtCore.Slot(str)
    def raiseSlug(self, slug: str) -> None:
        groups = []
        changed = False
        for group in self._stacks():
            if slug in group and group[-1] != slug:
                group = [s for s in group if s != slug] + [slug]
                changed = True
            groups.append(group)
        if changed:
            self._set_stacks(groups)
            self._reload()
            self.panesChanged.emit()

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
        # Configuration left list is module claim only — never dump raw DILL.
        doc = _load_module_doc(device_name)
        if not doc:
            return False
        claim = _claim_from_doc(doc)
        if (
            not claim["buttons"]
            and not claim["axes"]
            and not claim["hats"]
            and not claim["keys"]
        ):
            return False
        hid = int(hw_id)
        if kind == "button":
            return hid in claim["buttons"]
        if kind == "axis":
            return hid in claim["axes"]
        if kind == "hat":
            return hid in claim["hats"]
        if kind == "key":
            return hid in claim["keys"]
        return False

    @QtCore.Slot(str, result=int)
    def claimedCount(self, device_name: str) -> int:
        doc = _load_module_doc(device_name)
        if not doc:
            return 0
        claim = _claim_from_doc(doc)
        return (
            len(claim["buttons"])
            + len(claim["axes"])
            + len(claim["hats"])
            + len(claim["keys"])
        )

    @QtCore.Slot()
    def notifyClaims(self) -> None:
        self._reload()
        self.claimsChanged.emit()

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
        self.panesChanged.emit()


@ta.QmlElement
class DriverInputModel(QtCore.QAbstractListModel):
    """Full hardware list for Configure module (press-to-check)."""

    roles = {
        QtCore.Qt.ItemDataRole.UserRole + 1: QtCore.QByteArray(b"kind"),
        QtCore.Qt.ItemDataRole.UserRole + 2: QtCore.QByteArray(b"hwId"),
        QtCore.Qt.ItemDataRole.UserRole + 3: QtCore.QByteArray(b"label"),
        QtCore.Qt.ItemDataRole.UserRole + 4: QtCore.QByteArray(b"claimed"),
        QtCore.Qt.ItemDataRole.UserRole + 5: QtCore.QByteArray(b"friendly"),
        QtCore.Qt.ItemDataRole.UserRole + 6: QtCore.QByteArray(b"lit"),
    }

    changed = QtCore.Signal()
    rowActivated = QtCore.Signal(int)

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._guid = ""
        self._device_name = ""
        self._rows: list[dict] = []
        self._lit_index = -1
        try:
            listener = event_handler.EventListener()
            listener.joystick_event.connect(
                self._on_joy, QtCore.Qt.ConnectionType.QueuedConnection
            )
            listener.keyboard_event.connect(
                self._on_key, QtCore.Qt.ConnectionType.QueuedConnection
            )
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
        if self._is_keyboard():
            self._load_keyboard(claim)
            return
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
                        "lit": False,
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
                        "lit": False,
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
                        "lit": False,
                    }
                )
        self.beginResetModel()
        self._rows = rows
        self.endResetModel()
        self.changed.emit()

    def _is_keyboard(self) -> bool:
        name = (self._device_name or "").strip().lower()
        return name == "keyboard" or _norm_guid(self._guid) == _norm_guid(KEYBOARD_GUID)

    def _load_keyboard(self, claim: dict) -> None:
        saved = {int(k) for k in (claim.get("keys") or [])}
        friendly = claim.get("friendly") or {}
        skip = {"noname", "eraseeof", "zoom"}
        seen: set[int] = set()
        rows = []

        def add_key(key) -> None:
            hid = (int(key.scan_code) & 0xFFFF) | ((1 if key.is_extended else 0) << 16)
            if hid in seen:
                return
            seen.add(hid)
            rows.append(
                {
                    "kind": "key",
                    "hwId": hid,
                    "label": key.name,
                    "claimed": True if not saved else hid in saved,
                    "friendly": friendly.get(f"key:{hid}", ""),
                    "lit": False,
                }
            )

        for name, key in gremlin_keyboard.g_name_to_key.items():
            if name in skip:
                continue
            add_key(key)
        for ch in list("abcdefghijklmnopqrstuvwxyz0123456789`-=[]\\;'\",./"):
            try:
                add_key(gremlin_keyboard.key_from_name(ch))
            except Exception:
                pass
        for hid in saved:
            if hid in seen:
                continue
            scan = hid & 0xFFFF
            ext = bool(hid >> 16)
            try:
                add_key(gremlin_keyboard.key_from_code(scan, ext))
            except Exception:
                rows.append(
                    {
                        "kind": "key",
                        "hwId": hid,
                        "label": f"Key {scan}",
                        "claimed": True,
                        "friendly": friendly.get(f"key:{hid}", ""),
                        "lit": False,
                    }
                )
        self.beginResetModel()
        self._rows = rows
        self.endResetModel()
        self.changed.emit()

    def _on_key(self, event: event_handler.Event) -> None:
        if event is None or not self._is_keyboard():
            return
        if event.is_pressed is False:
            return
        ident = event.identifier
        try:
            scan, ext = ident[0], ident[1]
        except Exception:
            return
        hid = (int(scan) & 0xFFFF) | ((1 if ext else 0) << 16)
        try:
            label = gremlin_keyboard.key_from_code(int(scan), bool(ext)).name
        except Exception:
            label = f"Key {scan}"
        found = None
        for i, row in enumerate(self._rows):
            if row["kind"] == "key" and int(row["hwId"]) == hid:
                found = i
                break
        if found is None:
            self.beginInsertRows(QtCore.QModelIndex(), len(self._rows), len(self._rows))
            self._rows.append(
                {
                    "kind": "key",
                    "hwId": hid,
                    "label": label,
                    "claimed": True,
                    "friendly": "",
                    "lit": False,
                }
            )
            self.endInsertRows()
            found = len(self._rows) - 1
            self.changed.emit()
        self.markPressed("key", hid)

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
                    "lit": False,
                }
            )
        self.beginResetModel()
        self._rows = rows
        self.endResetModel()
        self.changed.emit()

    def _same_device(self, event: event_handler.Event) -> bool:
        if event is None:
            return False
        if _norm_guid(event.device_guid) == _norm_guid(self._guid):
            return True
        if not self._device_name:
            return False
        try:
            devices = list(device_initialization.joystick_devices())
        except Exception:
            devices = []
        want = _slug(self._device_name)
        ev = _norm_guid(event.device_guid)
        for dev in devices:
            if _norm_guid(dev.device_guid) != ev:
                continue
            if _slug(dev.name) == want or dev.name == self._device_name:
                self._guid = str(dev.device_guid)
                return True
        return False

    def _on_joy(self, event: event_handler.Event) -> None:
        try:
            if event is None or not self._rows:
                return
            if not self._same_device(event):
                return
            et = getattr(event, "event_type", None)
            kind = "button"
            if et == InputType.JoystickAxis:
                kind = "axis"
                try:
                    if abs(float(event.value)) < 0.35:
                        return
                except Exception:
                    return
            elif et == InputType.JoystickHat:
                kind = "hat"
                if getattr(event, "value", None) in (0, (0, 0), "center", None):
                    return
            elif et == InputType.JoystickButton:
                if event.is_pressed is False:
                    return
            try:
                hid = int(event.identifier)
            except Exception:
                return
            self.markPressed(kind, hid)
        except Exception:
            return

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

    def _set_lit(self, index: int, lit: bool) -> None:
        if not (0 <= index < len(self._rows)):
            return
        if bool(self._rows[index].get("lit")) == bool(lit):
            return
        self._rows[index]["lit"] = bool(lit)
        ix = self.index(index, 0)
        self.dataChanged.emit(ix, ix, [QtCore.Qt.ItemDataRole.UserRole + 6])

    @QtCore.Slot(str, int)
    def markPressed(self, kind: str, hw_id: int) -> None:
        for i, row in enumerate(self._rows):
            if row["kind"] == kind and int(row["hwId"]) == int(hw_id):
                if not row["claimed"]:
                    self.setClaimed(i, True)
                if self._lit_index == i:
                    return
                if self._lit_index >= 0:
                    self._set_lit(self._lit_index, False)
                self._lit_index = i
                self._set_lit(i, True)
                self.rowActivated.emit(i)
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
        keys = [int(r["hwId"]) for r in self._rows if r["kind"] == "key" and r["claimed"]]
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
            "keys": keys,
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
