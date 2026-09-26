# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.signal import signal
from gremlin.ui.util import to_local_path

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1

_IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp", ".bmp")

# Off unless someone is tracing a save. Same idea as the HiDHide log switch.
_persist_log = False


def persist_log(message: str) -> None:
    if _persist_log:
        print(message, flush=True)


def _photo_pose(raw) -> dict:
    src = raw if isinstance(raw, dict) else {}

    def _num(key: str, default: float) -> float:
        try:
            val = float(src.get(key, default))
        except (TypeError, ValueError):
            val = default
        return val

    scale = _num("scale", 1.0)
    if scale <= 0:
        scale = 1.0
    return {
        "scale": max(0.25, min(4.0, scale)),
        "offX": max(-1.0, min(1.0, _num("offX", 0.0))),
        "offY": max(-1.0, min(1.0, _num("offY", 0.0))),
        "rot": _num("rot", 0.0),
    }


def _install_root() -> Path:
    return Path(os.path.normcase(os.path.dirname(os.path.abspath(sys.argv[0]))))


def _maps_dir() -> Path:
    path = _install_root() / "qml" / "maps"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _plain_slug(device_name: str) -> str:
    raw = (device_name or "").strip().lower()
    if raw.endswith(".json"):
        raw = raw[:-5]
    out = []
    for ch in raw:
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "_":
            out.append("_")
    return "".join(out).strip("_")


def _slug(device_name: str) -> str:
    raw = (device_name or "device").strip().lower()
    if "gladiator" in raw and "ot" not in raw and ("evo r" in raw):
        return "vkb_evo_r"
    if "gladiator" in raw and "ot" not in raw and ("evo l" in raw):
        return "vkb_evo_l"
    return _plain_slug(device_name) or "device"


def _norm_guid(value: object) -> str:
    return str(value or "").upper().replace("{", "").replace("}", "").replace("-", "")


def _guid_for_name(device_name: str) -> str:
    wanted = (device_name or "").strip().lower()
    if not wanted:
        return ""
    try:
        from gremlin import device_initialization
        devices = list(device_initialization.physical_devices() or [])
        devices.extend(device_initialization.vjoy_devices() or [])
    except Exception:
        devices = []
    for dev in devices:
        name = str(getattr(dev, "name", "") or "")
        if name.strip().lower() != wanted:
            continue
        return _norm_guid(getattr(dev, "device_guid", ""))
    return ""


def _binding_store() -> dict[str, str]:
    from gremlin.config import Configuration
    from gremlin.types import PropertyType

    cfg = Configuration()
    section, group, name = "global", "internal", "module-file-bindings"
    # Register every launch. An existing value is kept. Skipping this when
    # the key already exists leaves it unregistered, and purge_unused deletes it.
    cfg.register(
        section,
        group,
        name,
        PropertyType.String,
        "{}",
        "Input module file chosen for each device.",
        {},
        False,
    )
    try:
        data = json.loads(cfg.value(section, group, name) or "{}")
    except (TypeError, json.JSONDecodeError):
        data = {}
    if not isinstance(data, dict):
        return {}
    return {str(key): str(value) for key, value in data.items() if key and value}


def _write_bindings(data: dict[str, str]) -> None:
    from gremlin.config import Configuration

    _binding_store()
    Configuration().set("global", "internal", "module-file-bindings", json.dumps(data))


def _name_key(device_name: str) -> str:
    slug = _plain_slug(device_name)
    return f"name:{slug}" if slug else ""


def resolve_module_slug(device_name: str, guid: str = "") -> str:
    data = _binding_store()
    key = _norm_guid(guid) or _guid_for_name(device_name)
    bound = data.get(key, "") if key else ""
    name_key = _name_key(device_name)
    if not bound and name_key:
        bound = data.get(name_key, "")
    if bound:
        return _plain_slug(bound) or _slug(device_name)
    return _slug(device_name)


def module_file_choices(device_name: str, guid: str = "") -> list[str]:
    names = sorted(path.stem for path in _maps_dir().glob("*.json") if path.is_file())
    current = resolve_module_slug(device_name, guid)
    if current and current not in names:
        names.append(current)
        names.sort()
    return names


def bind_module_file(device_name: str, guid: str, file_name: str) -> str:
    slug = _plain_slug(file_name)
    key = _norm_guid(guid) or _guid_for_name(device_name)
    if not slug or not key:
        return ""
    data = _binding_store()
    data[key] = slug
    name_key = _name_key(device_name)
    if name_key:
        data[name_key] = slug
    _write_bindings(data)
    persist_log(f"Persist bind file name={device_name!r} guid={guid!r} slug={slug!r}")
    return slug


def module_file_exists(device_name: str, guid: str = "") -> bool:
    slug = resolve_module_slug(device_name, guid)
    return bool(slug) and (_maps_dir() / f"{slug}.json").is_file()


def _live_devices() -> list:
    try:
        from gremlin import device_initialization
        devices = list(device_initialization.physical_devices() or [])
        devices.extend(device_initialization.vjoy_devices() or [])
        return devices
    except Exception:
        return []


def _users_of_slug(slug: str) -> set[str]:
    users: set[str] = set()
    for key, value in _binding_store().items():
        if _plain_slug(value) == slug:
            users.add(key)
    for dev in _live_devices():
        guid = _norm_guid(getattr(dev, "device_guid", ""))
        name = str(getattr(dev, "name", "") or "")
        if guid and name and resolve_module_slug(name, guid) == slug:
            users.add(guid)
    return users


def load_module_file(device_name: str, guid: str, source_url: str) -> str:
    try:
        src = to_local_path(source_url)
    except Exception:
        return ""
    if not src or not src.is_file() or src.suffix.lower() != ".json":
        return ""
    slug = _plain_slug(src.stem)
    if not slug:
        return ""
    dest = _maps_dir() / f"{slug}.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.resolve() != dest.resolve():
        if dest.exists():
            return ""
        shutil.copy2(src, dest)
    return bind_module_file(device_name, guid, slug)


def delete_module_file(device_name: str, guid: str) -> str:
    slug = resolve_module_slug(device_name, guid)
    key = _norm_guid(guid) or _guid_for_name(device_name)
    others = _users_of_slug(slug) - ({key} if key else set())
    if others:
        return "Another stick is using this file."
    path = _maps_dir() / f"{slug}.json"
    if path.is_file():
        path.unlink()
    data = _binding_store()
    for stored, value in list(data.items()):
        if _plain_slug(value) == slug or stored == key:
            data.pop(stored, None)
    _write_bindings(data)
    return ""


def maps_folder_url() -> str:
    return _maps_dir().as_uri()


def _stock_photo() -> Path:
    return _install_root() / "qml" / "images" / "vkb_gladiator_rig.jpg"


def _stock_photo_l() -> Path:
    return _install_root() / "qml" / "images" / "vkb_gladiator_evo_l.jpg"


def _safe_name(name: str, fallback: str = "image.jpg") -> str:
    raw = Path(name or "").name
    if not raw:
        return fallback
    keep = []
    for ch in raw:
        if ch.isalnum() or ch in "._-":
            keep.append(ch)
        else:
            keep.append("_")
    out = "".join(keep).strip("._") or fallback
    if Path(out).suffix.lower() not in _IMAGE_EXT:
        out = out + Path(fallback).suffix
    return out


def _explicit_ids(claim: dict, key: str) -> list[int]:
    raw = claim.get(key) if isinstance(claim, dict) else None
    ids: list[int] = []
    for item in raw or []:
        try:
            number = int(item)
        except (TypeError, ValueError):
            continue
        if number > 0:
            ids.append(number)
    return sorted(set(ids))


def _device_input_ids(guid: str) -> tuple[list[int], list[int], list[int]]:
    buttons: list[int] = []
    axes: list[int] = []
    hats: list[int] = []
    try:
        import dill
        info = dill.DILL.get_device_information_by_guid(dill.GUID.from_str(guid))
    except Exception:
        info = None
    if info is None:
        return buttons, axes, hats
    try:
        button_count = int(getattr(info, "button_count", 0) or 0)
    except (TypeError, ValueError):
        button_count = 0
    buttons = list(range(1, button_count + 1))
    try:
        hat_count = int(getattr(info, "hat_count", 0) or 0)
    except (TypeError, ValueError):
        hat_count = 0
    hats = list(range(1, hat_count + 1))
    for entry in getattr(info, "axis_map", None) or []:
        index = getattr(entry, "axis_index", None)
        if index is None and isinstance(entry, dict):
            index = entry.get("axis_index")
        try:
            number = int(index)
        except (TypeError, ValueError):
            continue
        if number > 0:
            axes.append(number)
    if not axes:
        try:
            axis_count = int(getattr(info, "axis_count", 0) or 0)
        except (TypeError, ValueError):
            axis_count = 0
        axes = list(range(1, axis_count + 1))
    return buttons, sorted(set(axes)), hats


def _profile_input_ids(guid: str) -> tuple[list[int], list[int], list[int]]:
    from gremlin.types import InputType
    from gremlin.ui import input_pairing as pairing

    buttons: list[int] = []
    axes: list[int] = []
    hats: list[int] = []
    for item in pairing._items_for_guid(guid):
        try:
            number = int(item.input_id)
        except (TypeError, ValueError):
            continue
        if number <= 0:
            continue
        kind = getattr(item, "input_type", None)
        if kind == InputType.JoystickAxis:
            axes.append(number)
        elif kind == InputType.JoystickHat:
            hats.append(number)
        elif kind == InputType.JoystickButton:
            buttons.append(number)
    return sorted(set(buttons)), sorted(set(axes)), sorted(set(hats))


def _output_labels(item) -> str:
    from gremlin.ui import input_pairing as pairing

    labels: list[str] = []
    seen: set[str] = set()

    def add(text: object) -> None:
        label = str(text or "").strip()
        if not label or label in seen:
            return
        seen.add(label)
        labels.append(label)

    for text in pairing._dest_labels_for_item(item):
        add(text)
    if item is None:
        return ""
    for seq in getattr(item, "action_sequences", []) or []:
        root = getattr(seq, "root_action", None)
        if root is None:
            continue
        for action in pairing._walk_actions(root):
            tag = str(getattr(action, "tag", "") or "")
            if tag in ("", "root", "map-to-vjoy", "map-to-xbox"):
                continue
            add(getattr(action, "name", "") or tag.replace("-", " "))
    return " + ".join(labels)


def _label_for(guid: str, kind: str, hw_id: int) -> str:
    from gremlin.types import InputType
    from gremlin.ui import input_pairing as pairing

    wanted = {
        "axis": InputType.JoystickAxis,
        "hat": InputType.JoystickHat,
    }.get(kind, InputType.JoystickButton)
    labels: list[str] = []
    for item in pairing._items_for_guid(guid):
        try:
            number = int(item.input_id)
        except (TypeError, ValueError):
            continue
        if number != hw_id or getattr(item, "input_type", None) != wanted:
            continue
        text = _output_labels(item)
        if text:
            labels.append(text)
    return " + ".join(labels)


def chips_for_guid(guid: str) -> list[dict]:
    """One chip per input this device's module reports, labeled from its outputs."""
    text = str(guid or "").strip()
    if not text:
        return []
    from gremlin.ui import input_pairing as pairing
    from gremlin.ui.module_model import _load_module_doc

    name = pairing._device_name(text)
    doc = _load_module_doc(name, text) if name else {}
    claim = doc.get("claim") if isinstance(doc, dict) and isinstance(doc.get("claim"), dict) else {}
    reported = _device_input_ids(text)
    stored = _profile_input_ids(text)
    groups = (
        ("btn", _explicit_ids(claim, "buttons"), reported[0], stored[0]),
        ("axis", _explicit_ids(claim, "axes"), reported[1], stored[1]),
        ("hat", _explicit_ids(claim, "hats"), reported[2], stored[2]),
    )
    rows: list[dict] = []
    for kind, claimed, live, saved in groups:
        ids = claimed or live or saved
        for hw_id in ids:
            rows.append({
                "kind": kind,
                "hwId": int(hw_id),
                "dest": _label_for(text, kind, int(hw_id)),
            })
    return rows


@ta.QmlElement
class HardwareProfile(QtCore.QObject):
    """Load / save a control.hardware JSON beside the Button Map."""

    documentChanged = QtCore.Signal()
    pathChanged = QtCore.Signal()
    imageChanged = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._device_name = "VKBsim Gladiator EVO R"
        self._text = "{}"
        self._path = ""
        self._peek_photo = ""
        self._device_guid = ""

    def _guid_for_this_device(self, device_name: str) -> str:
        # The object remembers one device. Do not use that id for a different name.
        guid = _norm_guid(self._device_guid)
        if not guid:
            return ""
        owned = _norm_guid(_guid_for_name(device_name))
        if not owned or owned != guid:
            return ""
        return str(self._device_guid)

    def _file_for(self, device_name: str) -> Path:
        slug = resolve_module_slug(device_name, self._guid_for_this_device(device_name))
        return _maps_dir() / f"{slug}.json"

    def _profile_dir(self, device_name: str) -> Path:
        slug = resolve_module_slug(device_name, self._guid_for_this_device(device_name))
        path = _maps_dir() / slug
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _library_dir(self) -> Path:
        path = _maps_dir() / "library"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _copy_file(self, src: Path, dest: Path) -> Path:
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.resolve() != src.resolve():
            shutil.copy2(src, dest)
        return dest

    def _into_library(self, src: Path) -> Path:
        dest = self._library_dir() / _safe_name(src.name, src.name)
        n = 1
        stem, ext = dest.stem, dest.suffix
        while dest.exists() and dest.resolve() != src.resolve():
            dest = self._library_dir() / f"{stem}_{n}{ext}"
            n += 1
        return self._copy_file(src, dest)

    def _resolve_existing(self, stored: str) -> Path | None:
        s = (stored or "").strip().replace("\\", "/")
        if not s:
            return None
        if s.startswith("file:"):
            try:
                p = to_local_path(s)
            except Exception:
                return None
            return p if p.is_file() else None
        p = Path(s)
        if not p.is_absolute():
            p = _install_root() / s
        if p.is_file():
            return p
        name = Path(s).name
        for cand in (
            _maps_dir() / name,
            _maps_dir() / "overlays" / name,
            _maps_dir() / "library" / name,
            _stock_photo(),
        ):
            if cand.is_file() and (name in cand.name or cand == _stock_photo()):
                if cand == _stock_photo() and "vkb_gladiator_rig" not in s and name != cand.name:
                    continue
                return cand
        stock = _stock_photo()
        if "vkb_gladiator_rig" in s and stock.is_file():
            return stock
        return None

    def _pack_assets(self, device_name: str, payload: dict) -> dict:
        folder = self._profile_dir(device_name)
        slug = folder.name
        image = str(payload.get("image") or "")
        src = self._resolve_existing(image) or _stock_photo()
        ext = src.suffix.lower() if src and src.suffix.lower() in _IMAGE_EXT else ".jpg"
        if not src or not src.is_file():
            payload["image"] = "qml/images/vkb_gladiator_rig.jpg"
        else:
            dest = folder / f"photo{ext}"
            self._copy_file(src, dest)
            payload["image"] = f"qml/maps/{slug}/{dest.name}"
        for node in payload.get("nodes") or []:
            if not isinstance(node, dict):
                continue
            rel = str(node.get("src") or "")
            if not rel or node.get("shape") != "image":
                continue
            ov = self._resolve_existing(rel)
            if not ov or not ov.is_file():
                continue
            dest = folder / _safe_name(ov.name, "overlay.png")
            if dest.exists() and dest.resolve() != ov.resolve():
                n = 1
                while dest.exists() and dest.resolve() != ov.resolve():
                    dest = folder / f"{dest.stem}_{n}{dest.suffix}"
                    n += 1
            self._copy_file(ov, dest)
            node["src"] = f"qml/maps/{slug}/{dest.name}"
            node.pop("srcUrl", None)
        return payload

    @QtCore.Slot(str, result=str)
    def defaultPath(self, device_name: str) -> str:
        return str(self._file_for(device_name))

    @QtCore.Slot(str, result=str)
    def defaultExportUrl(self, device_name: str) -> str:
        path = _maps_dir() / f"{_slug(device_name)}_map.zip"
        return path.as_uri()

    @QtCore.Slot(str, result="QVariant")
    def chips(self, guid: str):
        return chips_for_guid(guid)

    @QtCore.Slot(str)
    def setDeviceGuid(self, guid: str) -> None:
        self._device_guid = str(guid or "")

    @QtCore.Slot(str, result=str)
    def load(self, device_name: str) -> str:
        name = device_name or self._device_name
        path = self._file_for(name)
        self._path = str(path)
        self.pathChanged.emit()
        if path.is_file():
            self._text = path.read_text(encoding="utf-8")
        else:
            self._text = ""
        persist_log(
            f"Persist map load name={name!r} guid={self._device_guid!r} path={path} bytes={len(self._text)}"
        )
        self.documentChanged.emit()
        return self._text

    @QtCore.Slot(str, str, result=bool)
    def save(self, device_name: str, json_text: str) -> bool:
        name = device_name or self._device_name
        path = self._file_for(name)
        try:
            payload = json.loads(json_text)
        except json.JSONDecodeError:
            return False
        payload["kind"] = "control.hardware"
        payload["device"] = name
        payload["space"] = "world"
        payload["page"] = 32000
        payload["pageW"] = 32000
        payload["pageH"] = 18000
        payload["photoWell"] = 0.75
        payload.pop("worldRev", None)
        payload["photo"] = _photo_pose(payload.get("photo"))
        payload = self._pack_assets(name, payload)
        if path.is_file():
            try:
                existing = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                existing = {}
            if isinstance(existing, dict):
                for key in (
                    "claim",
                    "direction",
                    "boundGuidLocal",
                    "boundName",
                    "view",
                    "catalog",
                ):
                    if key in existing and key not in payload:
                        payload[key] = existing[key]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        kept = payload.get("claim") if isinstance(payload.get("claim"), dict) else {}
        persist_log(
            f"Persist map save name={name!r} guid={self._device_guid!r} path={path} "
            f"nodes={len(payload.get('nodes') or [])} "
            f"claimButtons={len(kept.get('buttons') or [])} "
            f"claimAxes={len(kept.get('axes') or [])}"
        )
        self._path = str(path)
        self._text = path.read_text(encoding="utf-8")
        self.pathChanged.emit()
        self.documentChanged.emit()
        self.imageChanged.emit()
        return True

    @QtCore.Slot(str, str, result=bool)
    def saveUi(self, device_name: str, json_text: str) -> bool:
        """Write only the ui block. Do not stamp page size or rewrite nodes."""
        name = device_name or self._device_name
        path = self._file_for(name)
        try:
            incoming = json.loads(json_text)
        except json.JSONDecodeError:
            return False
        if not path.is_file():
            return self.save(name, json_text)
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return False
        if not isinstance(payload, dict):
            return False
        payload["ui"] = incoming.get("ui", payload.get("ui") or {})
        payload.pop("worldRev", None)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        persist_log(f"Persist map ui name={name!r} guid={self._device_guid!r} path={path}")
        self._path = str(path)
        self._text = path.read_text(encoding="utf-8")
        self.pathChanged.emit()
        self.documentChanged.emit()
        return True

    @QtCore.Slot(str, str, result=str)
    def copyOverlay(self, source_url: str, device_name: str) -> str:
        src = to_local_path(source_url)
        if not src.is_file():
            return ""
        ext = src.suffix.lower() or ".png"
        if ext not in _IMAGE_EXT:
            ext = ".png"
        self._into_library(src)
        dest = self._profile_dir(device_name) / _safe_name(src.stem + ext, src.name)
        n = 1
        while dest.exists() and dest.resolve() != src.resolve():
            dest = self._profile_dir(device_name) / f"{src.stem}_{n}{ext}"
            n += 1
        self._copy_file(src, dest)
        self.imageChanged.emit()
        return f"qml/maps/{self._profile_dir(device_name).name}/{dest.name}"

    def _local_image(self, source_url: str) -> Path | None:
        raw = str(source_url or "").strip().split("?")[0].split("#")[0]
        if not raw:
            return None
        try:
            if raw.startswith("file:"):
                local = QtCore.QUrl(raw).toLocalFile()
                src = Path(local) if local else Path()
            else:
                src = to_local_path(raw)
        except Exception:
            src = Path(raw)
        return src if src.is_file() else None

    @QtCore.Slot(str, str, result=str)
    def keepPhoto(self, device_name: str, source_url: str) -> str:
        return self.copyImage(source_url, device_name)

    @QtCore.Slot(str, str, result=str)
    def copyImage(self, source_url: str, device_name: str) -> str:
        src = self._local_image(source_url)
        if src is None:
            return ""
        ext = src.suffix.lower() or ".jpg"
        if ext not in _IMAGE_EXT:
            ext = ".jpg"
        name = device_name or self._device_name
        slug = _slug(name)
        self._into_library(src)
        folder = _maps_dir() / slug
        folder.mkdir(parents=True, exist_ok=True)
        dest = folder / f"photo{ext}"
        for old in folder.glob("photo.*"):
            if old.resolve() != dest.resolve():
                try:
                    old.unlink()
                except OSError:
                    pass
        try:
            self._copy_file(src, dest)
        except OSError:
            dest = folder / f"photo_{src.stem}{ext}"
            self._copy_file(src, dest)
        rel = f"qml/maps/{slug}/{dest.name}"
        # Record the picture on this device's own file only. A shared module
        # binding must not change every other card.
        path = _maps_dir() / f"{slug}.json"
        if path.is_file():
            try:
                loaded = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                loaded = None
            if isinstance(loaded, dict):
                loaded["image"] = rel
                path.write_text(json.dumps(loaded, indent=2) + "\n", encoding="utf-8")
        persist_log(f"Persist photo name={name!r} guid={self._device_guid!r} path={path} image={rel!r}")
        self._path = str(path)
        self.pathChanged.emit()
        self.documentChanged.emit()
        self.imageChanged.emit()
        return rel

    @QtCore.Slot(str, result=bool)
    def clearImage(self, device_name: str) -> bool:
        name = device_name or self._device_name
        folder = _maps_dir() / _slug(name)
        for p in folder.glob("photo.*"):
            try:
                p.unlink()
            except OSError:
                return False
        for ext in _IMAGE_EXT:
            p = _maps_dir() / f"{_slug(name)}_photo{ext}"
            if p.is_file():
                try:
                    p.unlink()
                except OSError:
                    return False
        self.imageChanged.emit()
        return True

    @QtCore.Slot(result=str)
    def imagesFolderUrl(self) -> str:
        path = _install_root() / "qml" / "images"
        path.mkdir(parents=True, exist_ok=True)
        return QtCore.QUrl.fromLocalFile(str(path)).toString()

    @QtCore.Slot(str, result=str)
    def imageUrl(self, stored: str) -> str:
        found = self._resolve_existing(stored)
        if found and found.is_file():
            return found.as_uri()
        s = (stored or "").strip().replace("\\", "/")
        if not s or "vkb_gladiator_rig" in s:
            return ""
        if s.startswith("file:") or s.startswith("qrc:"):
            return s
        return ""

    @QtCore.Slot(str, result=str)
    def profilePhotoUrl(self, device_name: str) -> str:
        own = _maps_dir() / _slug(device_name)
        for p in sorted(own.glob("photo.*")):
            if p.is_file():
                return p.as_uri() + f"?t={int(p.stat().st_mtime_ns)}"
        text = self.load(device_name)
        try:
            doc = json.loads(text) if text else {}
        except json.JSONDecodeError:
            doc = {}
        found = self._resolve_existing(str(doc.get("image") or ""))
        if found and found.is_file():
            # Never reuse the EVO R grip shot for a different module.
            if found == _stock_photo() and _slug(device_name) != "vkb_evo_r":
                return ""
            try:
                # A picture saved for another device lives in that device's folder.
                if found.resolve().parent != own.resolve():
                    found = None
            except OSError:
                found = None
            if found is not None:
                return found.as_uri() + f"?t={int(found.stat().st_mtime_ns)}"
        if _slug(device_name) == "vkb_evo_r":
            stock = _stock_photo()
            return stock.as_uri() if stock.is_file() else ""
        if _slug(device_name) == "vkb_evo_l":
            stock = _stock_photo_l()
            if stock.is_file():
                return stock.as_uri()
            packed = _maps_dir() / "vkb_evo_l" / "photo.jpg"
            return packed.as_uri() if packed.is_file() else ""
        return ""

    def _plate_count(self, payload: dict) -> int:
        n = 0
        for node in payload.get("nodes") or []:
            if isinstance(node, dict) and node.get("shape") == "image" and node.get("src"):
                n += 1
        return n

    @QtCore.Slot(str, result=str)
    def peekLocal(self, device_name: str) -> str:
        name = device_name or self._device_name
        text = self.load(name)
        try:
            doc = json.loads(text) if text else {}
        except json.JSONDecodeError:
            doc = {}
        device = str(doc.get("device") or name)
        return json.dumps({
            "ok": True,
            "device": device,
            "slug": _slug(device),
            "photoUrl": self.profilePhotoUrl(name),
            "plates": self._plate_count(doc),
            "fallback": "vkb_gladiator_rig" in str(doc.get("image") or "") or not doc,
        })

    @QtCore.Slot(str, result=str)
    def peekZip(self, zip_url: str) -> str:
        try:
            src = to_local_path(zip_url)
        except Exception:
            return json.dumps({"ok": False, "error": "Cannot read that file."})
        if not src or not src.is_file():
            return json.dumps({"ok": False, "error": "File not found."})
        try:
            with zipfile.ZipFile(src, "r") as zf:
                names = zf.namelist()
                json_name = "map.json" if "map.json" in names else next(
                    (n for n in names if n.lower().endswith(".json") and "/" not in n.strip("/")),
                    "",
                )
                if not json_name:
                    return json.dumps({"ok": False, "error": "No map.json in this zip."})
                doc = json.loads(zf.read(json_name).decode("utf-8"))
                device = str(doc.get("device") or "")
                photo_name = Path(str(doc.get("image") or "photo.jpg")).name
                photo_member = photo_name if photo_name in names else next(
                    (n for n in names if Path(n).name.startswith("photo")),
                    "",
                )
                photo_url = ""
                fallback = False
                if photo_member:
                    data = zf.read(photo_member)
                    tmp = Path(tempfile.gettempdir()) / f"jg_peek_{_slug(device) or 'map'}{Path(photo_member).suffix}"
                    tmp.write_bytes(data)
                    self._peek_photo = str(tmp)
                    photo_url = tmp.as_uri()
                else:
                    stock = _stock_photo()
                    photo_url = stock.as_uri() if stock.is_file() else ""
                    fallback = True
                return json.dumps({
                    "ok": True,
                    "device": device,
                    "slug": _slug(device),
                    "photoUrl": photo_url,
                    "plates": self._plate_count(doc),
                    "fallback": fallback,
                })
        except zipfile.BadZipFile:
            return json.dumps({"ok": False, "error": "Not a valid zip."})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @QtCore.Slot(str, str, result=str)
    def exportMap(self, device_name: str, dest_url: str) -> str:
        name = device_name or self._device_name
        if not name:
            return json.dumps({"ok": False, "error": "Select a Status card first."})
        path = self._file_for(name)
        if not path.is_file():
            return json.dumps({"ok": False, "error": "Save the module first."})
        try:
            dest = to_local_path(dest_url)
        except Exception:
            return json.dumps({"ok": False, "error": "Cannot write that path."})
        if not dest or not str(dest).strip() or dest.name in ("", ".zip"):
            return json.dumps({"ok": False, "error": "Cannot write that path."})
        if dest.suffix.lower() != ".zip":
            dest = dest.with_suffix(".zip")
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return json.dumps({"ok": False, "error": "Profile JSON is not valid."})
        payload = self._pack_assets(name, payload)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        persist_log(f"Persist export rewrite name={name!r} guid={self._device_guid!r} path={path}")
        packed = json.loads(json.dumps(payload))
        packed.pop("boundGuidLocal", None)
        files = []
        photo = self._resolve_existing(str(packed.get("image") or ""))
        if photo and photo.is_file():
            files.append((photo, photo.name if photo.name.startswith("photo") else "photo" + photo.suffix.lower()))
            packed["image"] = files[-1][1]
        for node in packed.get("nodes") or []:
            if not isinstance(node, dict) or node.get("shape") != "image":
                continue
            ov = self._resolve_existing(str(node.get("src") or ""))
            if not ov or not ov.is_file():
                continue
            arc = _safe_name(ov.name, "overlay.png")
            used = {a for _, a in files}
            if arc in used:
                n = 1
                stem, ext = Path(arc).stem, Path(arc).suffix
                while f"{stem}_{n}{ext}" in used:
                    n += 1
                arc = f"{stem}_{n}{ext}"
            files.append((ov, arc))
            node["src"] = arc
            node.pop("srcUrl", None)
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
                zf.writestr("map.json", json.dumps(packed, indent=2) + "\n")
                for src, arc in files:
                    zf.write(src, arc)
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})
        return json.dumps({"ok": True, "path": str(dest), "device": name})

    @QtCore.Slot(str, result=str)
    def importMap(self, zip_url: str) -> str:
        try:
            src = to_local_path(zip_url)
        except Exception:
            return json.dumps({"ok": False, "error": "Cannot read that file."})
        if not src or not src.is_file():
            return json.dumps({"ok": False, "error": "File not found."})
        try:
            with zipfile.ZipFile(src, "r") as zf:
                names = zf.namelist()
                json_name = "map.json" if "map.json" in names else next(
                    (n for n in names if n.lower().endswith(".json") and n.count("/") == 0),
                    "",
                )
                if not json_name:
                    return json.dumps({"ok": False, "error": "No map.json in this zip."})
                payload = json.loads(zf.read(json_name).decode("utf-8"))
                device = str(payload.get("device") or "").strip()
                if not device:
                    return json.dumps({"ok": False, "error": "Zip has no device name."})
                slug = _slug(device)
                folder = self._profile_dir(device)
                extracted = {}
                for member in names:
                    if member.endswith("/") or member == json_name:
                        continue
                    base = Path(member).name
                    if not base or Path(base).suffix.lower() not in _IMAGE_EXT:
                        continue
                    dest = folder / _safe_name(base, base)
                    dest.write_bytes(zf.read(member))
                    extracted[base] = dest
                    extracted[member] = dest
                photo_key = Path(str(payload.get("image") or "photo.jpg")).name
                if photo_key in extracted:
                    payload["image"] = f"qml/maps/{slug}/{extracted[photo_key].name}"
                for node in payload.get("nodes") or []:
                    if not isinstance(node, dict):
                        continue
                    rel = str(node.get("src") or "")
                    key = Path(rel).name
                    if key in extracted:
                        node["src"] = f"qml/maps/{slug}/{extracted[key].name}"
                    node.pop("srcUrl", None)
                payload["kind"] = "control.hardware"
                payload["device"] = device
                payload["space"] = "world"
                payload["page"] = 32000
                payload["pageW"] = 32000
                payload["pageH"] = 18000
                payload["photoWell"] = 0.75
                payload.pop("worldRev", None)
                payload["photo"] = _photo_pose(payload.get("photo"))
                out = self._file_for(device)
                out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
                self._path = str(out)
                self._text = out.read_text(encoding="utf-8")
                self.pathChanged.emit()
                self.documentChanged.emit()
                self.imageChanged.emit()
                signal.configChanged.emit()
                return json.dumps({"ok": True, "device": device, "slug": slug})
        except zipfile.BadZipFile:
            return json.dumps({"ok": False, "error": "Not a valid zip."})
        except Exception as exc:
            return json.dumps({"ok": False, "error": str(exc)})

    @QtCore.Property(str, notify=pathChanged)
    def path(self) -> str:
        return self._path

    @QtCore.Property(str, notify=documentChanged)
    def text(self) -> str:
        return self._text
