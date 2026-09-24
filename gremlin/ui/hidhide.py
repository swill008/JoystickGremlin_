# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only
"""HidHide control device client. Does not ship or install the driver."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from PySide6 import QtCore, QtGui

from gremlin import config
from gremlin.types import PropertyType
import gremlin.ui.type_aliases as ta

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1

_CFG_SECTION = "display"
_CFG_GROUP = "hidhide"
_CFG_GAMES = "games"
_DOWNLOAD = "https://github.com/nefarius/HidHide/releases"

_DEVICE_TYPE = 32769
_METHOD_BUFFERED = 0
_FILE_READ_DATA = 1


def _ctl(function: int) -> int:
    return (_DEVICE_TYPE << 16) | (_FILE_READ_DATA << 14) | (function << 2) | _METHOD_BUFFERED


IOCTL_GET_WHITELIST = _ctl(2048)
IOCTL_SET_WHITELIST = _ctl(2049)
IOCTL_GET_BLACKLIST = _ctl(2050)
IOCTL_SET_BLACKLIST = _ctl(2051)
IOCTL_GET_ACTIVE = _ctl(2052)
IOCTL_SET_ACTIVE = _ctl(2053)

_GENERIC_READ = 0x80000000
_SHARE = 0x00000007
_OPEN_EXISTING = 3
_INVALID = 0xFFFFFFFFFFFFFFFF


def _ensure_options() -> None:
    cfg = config.Configuration()
    try:
        cfg.register(
            _CFG_SECTION,
            _CFG_GROUP,
            _CFG_GAMES,
            PropertyType.String,
            "[]",
            "Hardware Hide game whitelist (name + exe path).",
            {},
            True,
        )
    except Exception:
        pass


def _load_games() -> list[dict]:
    _ensure_options()
    raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_GAMES) or "[]")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    out = []
    if isinstance(data, list):
        for row in data:
            if not isinstance(row, dict):
                continue
            path = str(row.get("path") or "").strip()
            if not path:
                continue
            name = str(row.get("name") or Path(path).stem)
            out.append({"name": name, "path": path})
    return out


def _save_games(rows: list[dict]) -> None:
    _ensure_options()
    packed = json.dumps(
        [{"name": r["name"], "path": r["path"]} for r in rows],
        ensure_ascii=True,
    )
    try:
        config.Configuration().set(_CFG_SECTION, _CFG_GROUP, _CFG_GAMES, packed)
    except Exception:
        pass


def _gremlin_exe() -> str:
    if getattr(sys, "frozen", False):
        return str(Path(sys.executable).resolve())
    return str(Path(sys.argv[0]).resolve()) if sys.argv else sys.executable


def _open_control():
    if os.name != "nt":
        return None
    k32 = __import__("ctypes").WinDLL("kernel32", use_last_error=True)
    handle = k32.CreateFileW(
        "\\\\.\\HidHide",
        _GENERIC_READ,
        _SHARE,
        None,
        _OPEN_EXISTING,
        0,
        None,
    )
    if handle == _INVALID or handle == -1:
        return None
    return handle


def _close(handle) -> None:
    if handle:
        __import__("ctypes").windll.kernel32.CloseHandle(handle)


def _ioctl(handle, code: int, inn: bytes | None = None, out_size: int = 0) -> tuple[bool, bytes]:
    import ctypes
    from ctypes import wintypes

    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    returned = wintypes.DWORD(0)
    in_buf = ctypes.create_string_buffer(inn) if inn else None
    in_len = len(inn) if inn else 0
    out_buf = ctypes.create_string_buffer(out_size) if out_size else None
    ok = k32.DeviceIoControl(
        handle,
        ctypes.c_ulong(code),
        in_buf,
        in_len,
        out_buf,
        out_size,
        ctypes.byref(returned),
        None,
    )
    data = out_buf.raw[: returned.value] if out_buf else b""
    return bool(ok), data


def _decode_multi_sz(raw: bytes) -> list[str]:
    if not raw:
        return []
    text = raw.decode("utf-16-le", errors="ignore")
    parts = text.split("\x00")
    return [p for p in parts if p]


def _encode_multi_sz(items: list[str]) -> bytes:
    body = "\x00".join(items) + "\x00\x00"
    raw = body.encode("utf-16-le")
    if len(raw) % 2:
        raw += b"\x00"
    return raw


def _get_multi(code: int) -> list[str]:
    handle = _open_control()
    if handle is None:
        return []
    try:
        size = 4096
        for _ in range(6):
            ok, data = _ioctl(handle, code, None, size)
            if ok:
                return _decode_multi_sz(data)
            size *= 2
        return []
    finally:
        _close(handle)


def _set_multi(code: int, items: list[str]) -> bool:
    handle = _open_control()
    if handle is None:
        return False
    try:
        payload = _encode_multi_sz(items)
        ok, _ = _ioctl(handle, code, payload, 0)
        return ok
    finally:
        _close(handle)


def driver_present() -> bool:
    handle = _open_control()
    if handle is None:
        return False
    _close(handle)
    return True


def get_active() -> bool:
    handle = _open_control()
    if handle is None:
        return False
    try:
        ok, data = _ioctl(handle, IOCTL_GET_ACTIVE, None, 1)
        return ok and bool(data and data[0])
    finally:
        _close(handle)


def set_active(on: bool) -> bool:
    handle = _open_control()
    if handle is None:
        return False
    try:
        ok, _ = _ioctl(handle, IOCTL_SET_ACTIVE, bytes([1 if on else 0]), 0)
        return ok
    finally:
        _close(handle)


def get_blacklist() -> list[str]:
    return _get_multi(IOCTL_GET_BLACKLIST)


def set_blacklist(ids: list[str]) -> bool:
    return _set_multi(IOCTL_SET_BLACKLIST, ids)


def get_whitelist() -> list[str]:
    return _get_multi(IOCTL_GET_WHITELIST)


def set_whitelist(paths: list[str]) -> bool:
    return _set_multi(IOCTL_SET_WHITELIST, paths)


def _is_virtual(instance: str, name: str) -> bool:
    blob = f"{instance} {name}".upper()
    return any(
        tag in blob
        for tag in (
            "VID_1234",
            "VJOY",
            "VIGEM",
            "XBOX 360 CONTROLLER",
            "VIRTUAL HID",
            "ROOT\\SYSTEM",
        )
    )


def _is_keyboard_mouse(instance: str, name: str) -> bool:
    blob = f"{instance} {name}".upper()
    return "KEYBOARD" in blob or "MOUSE" in blob or "&MI_01" in blob and "KBD" in blob


def list_hid_devices() -> list[dict]:
    """System-wide HID instance IDs HidHide can hide. Not Gremlin modules."""
    if os.name != "nt":
        return []
    try:
        return _list_hid_cfgmgr()
    except Exception:
        return []


def _list_hid_cfgmgr() -> list[dict]:
    import ctypes
    from ctypes import wintypes

    cfg = ctypes.WinDLL("cfgmgr32", use_last_error=True)
    CM_GETIDLIST_FILTER_ENUMERATOR = 0x00000001
    CR_SUCCESS = 0
    size = wintypes.ULONG(0)
    filt = "HID"
    flags = CM_GETIDLIST_FILTER_ENUMERATOR
    if cfg.CM_Get_Device_ID_List_SizeW(ctypes.byref(size), filt, flags) != CR_SUCCESS:
        filt = None
        flags = 0
        if cfg.CM_Get_Device_ID_List_SizeW(ctypes.byref(size), filt, flags) != CR_SUCCESS:
            return []
    if size.value < 2:
        return []
    buf = ctypes.create_unicode_buffer(size.value)
    if cfg.CM_Get_Device_ID_ListW(filt, buf, size, flags) != CR_SUCCESS:
        return []
    text = ctypes.wstring_at(ctypes.addressof(buf), size.value)
    ids = [p for p in text.split(chr(0)) if p]
    out = []
    seen = set()
    for instance in ids:
        up = instance.upper()
        if not up.startswith("HID"):
            continue
        if instance in seen:
            continue
        seen.add(instance)
        name = _friendly_name(instance) or instance
        if _is_virtual(instance, name):
            continue
        out.append(
            {
                "instanceId": instance,
                "name": name,
                "canHide": not _is_keyboard_mouse(instance, name),
            }
        )
    out.sort(key=lambda r: r["name"].lower())
    return out


def _friendly_name(instance: str) -> str:
    import ctypes
    from ctypes import wintypes

    setup = ctypes.WinDLL("setupapi", use_last_error=True)

    class SP_DEVINFO_DATA(ctypes.Structure):
        _fields_ = [
            ("cbSize", wintypes.DWORD),
            ("ClassGuid", ctypes.c_byte * 16),
            ("DevInst", wintypes.DWORD),
            ("Reserved", ctypes.c_void_p),
        ]

    setup.SetupDiCreateDeviceInfoList.restype = ctypes.c_void_p
    handle = setup.SetupDiCreateDeviceInfoList(None, None)
    if not handle or handle == ctypes.c_void_p(-1).value:
        return ""
    try:
        info = SP_DEVINFO_DATA()
        info.cbSize = ctypes.sizeof(SP_DEVINFO_DATA)
        if not setup.SetupDiOpenDeviceInfoW(handle, instance, None, 0, ctypes.byref(info)):
            return ""
        name_buf = ctypes.create_unicode_buffer(512)
        required = wintypes.DWORD(0)
        for prop in (12, 0):
            if setup.SetupDiGetDeviceRegistryPropertyW(
                handle,
                ctypes.byref(info),
                prop,
                None,
                name_buf,
                ctypes.sizeof(name_buf),
                ctypes.byref(required),
            ):
                return name_buf.value or ""
        return ""
    finally:
        setup.SetupDiDestroyDeviceInfoList(handle)


@ta.QmlElement
class HidHideModel(QtCore.QObject):
    """System-wide HidHide panel. Persistent cloak, devices, and game list."""

    changed = QtCore.Signal()

    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        self._present = False
        self._active = False
        self._devices: list[dict] = []
        self._games: list[dict] = []
        _ensure_options()
        self.reload()

    def reload(self) -> None:
        self._present = driver_present()
        self._active = get_active() if self._present else False
        hidden = {i.upper() for i in get_blacklist()} if self._present else set()
        self._devices = []
        try:
            rows = list_hid_devices()
        except Exception:
            rows = []
        for row in rows:
            item = dict(row)
            item["hidden"] = item["instanceId"].upper() in hidden
            self._devices.append(item)
        if self._present:
            for hid in get_blacklist():
                if not any(d["instanceId"].upper() == hid.upper() for d in self._devices):
                    self._devices.append(
                        {
                            "instanceId": hid,
                            "name": hid,
                            "canHide": True,
                            "hidden": True,
                        }
                    )
        self._games = _load_games()
        self.changed.emit()

    @QtCore.Property(bool, notify=changed)
    def installed(self) -> bool:
        return self._present

    @QtCore.Property(str, constant=True)
    def downloadUrl(self) -> str:
        return _DOWNLOAD

    @QtCore.Property(bool, notify=changed)
    def cloakOn(self) -> bool:
        return self._active

    @QtCore.Property(int, notify=changed)
    def deviceCount(self) -> int:
        return len(self._devices)

    @QtCore.Property(int, notify=changed)
    def gameCount(self) -> int:
        return len(self._games)

    @QtCore.Slot(int, result="QVariant")
    def deviceAt(self, index: int):
        if 0 <= index < len(self._devices):
            return self._devices[index]
        return {}

    @QtCore.Slot(int, result="QVariant")
    def gameAt(self, index: int):
        if 0 <= index < len(self._games):
            return self._games[index]
        return {}

    @QtCore.Slot(bool, result=bool)
    def setCloak(self, on: bool) -> bool:
        if not self._present:
            return False
        self._ensure_gremlin_whitelisted()
        if not set_active(bool(on)):
            return False
        self._active = bool(on)
        self.changed.emit()
        return True

    @QtCore.Slot(str, bool, result=bool)
    def setDeviceHidden(self, instance_id: str, hidden: bool) -> bool:
        if not self._present or not instance_id:
            return False
        current = get_blacklist()
        key = instance_id.upper()
        kept = [x for x in current if x.upper() != key]
        if hidden:
            kept.append(instance_id)
        if not set_blacklist(kept):
            return False
        self.reload()
        return True

    @QtCore.Slot(str, str, result=bool)
    def addGame(self, name: str, path: str) -> bool:
        path = str(Path(path).resolve()) if path else ""
        if not path:
            return False
        label = (name or "").strip() or Path(path).stem
        rows = [r for r in self._games if Path(r["path"]).resolve().as_posix().lower() != Path(path).as_posix().lower()]
        rows.append({"name": label, "path": path})
        rows.sort(key=lambda r: r["name"].lower())
        _save_games(rows)
        self._games = rows
        self._sync_whitelist()
        self.changed.emit()
        return True

    @QtCore.Slot(str, result=bool)
    def removeGame(self, path: str) -> bool:
        rows = [r for r in self._games if r["path"] != path]
        _save_games(rows)
        self._games = rows
        self._sync_whitelist()
        self.changed.emit()
        return True

    @QtCore.Slot()
    def refresh(self) -> None:
        self.reload()

    @QtCore.Slot()
    def openDownload(self) -> None:
        QtGui.QDesktopServices.openUrl(QtCore.QUrl(_DOWNLOAD))

    def _ensure_gremlin_whitelisted(self) -> None:
        self._sync_whitelist()

    def _sync_whitelist(self) -> None:
        if not self._present:
            return
        current = get_whitelist()
        wanted = {_gremlin_exe()}
        for row in self._games:
            wanted.add(row["path"])
        merged = []
        seen = set()
        for item in list(current) + list(wanted):
            key = item.lower()
            if key in seen or not item:
                continue
            seen.add(key)
            merged.append(item)
        set_whitelist(merged)
