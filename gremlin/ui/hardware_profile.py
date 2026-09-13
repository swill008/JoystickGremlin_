# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

from PySide6 import QtCore

import gremlin.ui.type_aliases as ta
from gremlin.ui.util import to_local_path

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1


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
    out = []
    for ch in raw:
        if ch.isalnum():
            out.append(ch)
        elif out and out[-1] != "_":
            out.append("_")
    return "".join(out).strip("_") or "device"


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

    def _file_for(self, device_name: str) -> Path:
        return _maps_dir() / f"{_slug(device_name)}.json"

    @QtCore.Slot(str, result=str)
    def defaultPath(self, device_name: str) -> str:
        return str(self._file_for(device_name))

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
        image = str(payload.get("image") or "")
        payload["image"] = self.toRelative(image)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        self._path = str(path)
        self._text = path.read_text(encoding="utf-8")
        self.pathChanged.emit()
        self.documentChanged.emit()
        return True

    @QtCore.Slot(str, str, result=str)
    def copyImage(self, source_url: str, device_name: str) -> str:
        src = to_local_path(source_url)
        if not src.is_file():
            return ""
        ext = src.suffix.lower() or ".jpg"
        if ext not in (".jpg", ".jpeg", ".png", ".webp", ".bmp"):
            ext = ".jpg"
        dest = _maps_dir() / f"{_slug(device_name)}_photo{ext}"
        shutil.copy2(src, dest)
        self.imageChanged.emit()
        return f"qml/maps/{dest.name}"

    @QtCore.Slot(str, result=bool)
    def clearImage(self, device_name: str) -> bool:
        name = device_name or self._device_name
        for ext in (".jpg", ".jpeg", ".png", ".webp", ".bmp"):
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
        s = (stored or "").strip().replace("\\", "/")
        if not s or "vkb_gladiator_rig" in s:
            return ""
        if s.startswith("file:") or s.startswith("qrc:"):
            return s
        p = Path(s)
        if not p.is_absolute():
            p = _install_root() / s
        if p.is_file():
            return p.as_uri()
        alt = _maps_dir() / Path(s).name
        if alt.is_file():
            return alt.as_uri()
        return ""

    @QtCore.Slot(str, result=str)
    def toRelative(self, url_or_path: str) -> str:
        s = (url_or_path or "").strip().replace("\\", "/")
        if not s or "vkb_gladiator_rig" in s:
            return "qml/images/vkb_gladiator_rig.jpg"
        if s.startswith("qml/maps/"):
            return s
        if s.startswith("qml/images/"):
            return s
        try:
            src = to_local_path(url_or_path)
        except Exception:
            src = Path(s)
        name = src.name
        if name and "_photo" in name:
            return f"qml/maps/{name}"
        if "qml/maps/" in s:
            return "qml/maps/" + s.split("qml/maps/")[-1]
        return s

    @QtCore.Property(str, notify=pathChanged)
    def path(self) -> str:
        return self._path

    @QtCore.Property(str, notify=documentChanged)
    def text(self) -> str:
        return self._text
