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
from gremlin.ui.util import to_local_path

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1

_IMAGE_EXT = (".jpg", ".jpeg", ".png", ".webp", ".bmp")


def _install_root() -> Path:
    return Path(os.path.normcase(os.path.dirname(os.path.abspath(sys.argv[0]))))


def _maps_dir() -> Path:
    path = _install_root() / "qml" / "maps"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _slug(device_name: str) -> str:
    raw = (device_name or "device").strip().lower()
    if "gladiator" in raw and ("evo r" in raw or "ot r" in raw):
        return "vkb_evo_r"
    if "gladiator" in raw and ("evo l" in raw or "ot l" in raw):
        return "vkb_evo_l"
    out = []
    for ch in raw:
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "_":
            out.append("_")
    return "".join(out).strip("_") or "device"


def _stock_photo() -> Path:
    return _install_root() / "qml" / "images" / "vkb_gladiator_rig.jpg"


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

    def _file_for(self, device_name: str) -> Path:
        return _maps_dir() / f"{_slug(device_name)}.json"

    def _profile_dir(self, device_name: str) -> Path:
        path = _maps_dir() / _slug(device_name)
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
        for folder in _maps_dir().iterdir() if _maps_dir().is_dir() else []:
            if folder.is_dir():
                hit = folder / name
                if hit.is_file():
                    return hit
        stock = _stock_photo()
        if "vkb_gladiator_rig" in s and stock.is_file():
            return stock
        return None

    def _pack_assets(self, device_name: str, payload: dict) -> dict:
        slug = _slug(device_name)
        folder = self._profile_dir(device_name)
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

    @QtCore.Slot(str, result=str)
    def slugFor(self, device_name: str) -> str:
        return _slug(device_name)

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
        payload = self._pack_assets(name, payload)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
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
        return f"qml/maps/{_slug(device_name)}/{dest.name}"

    @QtCore.Slot(str, str, result=str)
    def copyImage(self, source_url: str, device_name: str) -> str:
        src = to_local_path(source_url)
        if not src.is_file():
            return ""
        ext = src.suffix.lower() or ".jpg"
        if ext not in _IMAGE_EXT:
            ext = ".jpg"
        self._into_library(src)
        dest = self._profile_dir(device_name) / f"photo{ext}"
        self._copy_file(src, dest)
        self.imageChanged.emit()
        return f"qml/maps/{_slug(device_name)}/{dest.name}"

    @QtCore.Slot(str, result=bool)
    def clearImage(self, device_name: str) -> bool:
        name = device_name or self._device_name
        folder = self._profile_dir(name)
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
    def toRelative(self, url_or_path: str) -> str:
        s = (url_or_path or "").strip().replace("\\", "/")
        if not s or "vkb_gladiator_rig" in s:
            return "qml/images/vkb_gladiator_rig.jpg"
        if s.startswith("qml/maps/") or s.startswith("qml/images/"):
            return s
        try:
            src = to_local_path(url_or_path)
        except Exception:
            src = Path(s)
        name = src.name
        parent = src.parent.name
        if parent and (src.parent.parent / parent).exists() and parent not in ("maps", "images", "overlays", "library"):
            return f"qml/maps/{parent}/{name}"
        if name and name.startswith("photo"):
            return f"qml/maps/{name}"
        if "/overlays/" in s.replace("\\", "/"):
            return f"qml/maps/overlays/{name}"
        if "/library/" in s.replace("\\", "/"):
            return f"qml/maps/library/{name}"
        if "qml/maps/" in s:
            return "qml/maps/" + s.split("qml/maps/")[-1]
        return s

    @QtCore.Slot(str, result=str)
    def profilePhotoUrl(self, device_name: str) -> str:
        folder = self._profile_dir(device_name)
        for p in sorted(folder.glob("photo.*")):
            if p.is_file():
                return p.as_uri()
        text = self.load(device_name)
        try:
            doc = json.loads(text) if text else {}
        except json.JSONDecodeError:
            doc = {}
        found = self._resolve_existing(str(doc.get("image") or ""))
        if found:
            return found.as_uri()
        stock = _stock_photo()
        return stock.as_uri() if stock.is_file() else ""

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
        if not src.is_file():
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
        path = self._file_for(name)
        if not path.is_file():
            return json.dumps({"ok": False, "error": "Save the mapping first."})
        try:
            dest = to_local_path(dest_url)
        except Exception:
            return json.dumps({"ok": False, "error": "Cannot write that path."})
        if dest.suffix.lower() != ".zip":
            dest = dest.with_suffix(".zip")
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return json.dumps({"ok": False, "error": "Profile JSON is not valid."})
        payload = self._pack_assets(name, payload)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        files = []
        photo = self._resolve_existing(str(payload.get("image") or ""))
        if photo and photo.is_file():
            files.append((photo, photo.name if photo.name.startswith("photo") else "photo" + photo.suffix.lower()))
            payload["image"] = files[-1][1]
        for node in payload.get("nodes") or []:
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
                zf.writestr("map.json", json.dumps(payload, indent=2) + "\n")
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
        if not src.is_file():
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
                out = self._file_for(device)
                out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
                self._path = str(out)
                self._text = out.read_text(encoding="utf-8")
                self.pathChanged.emit()
                self.documentChanged.emit()
                self.imageChanged.emit()
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
