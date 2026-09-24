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
_CFG_PHOTOS = "photos"
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
IOCTL_ADD_SESSION_BLACKLIST = _ctl(2056)
IOCTL_CLR_SESSION_BLACKLIST = _ctl(2057)

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
        cfg.register(
            _CFG_SECTION,
            _CFG_GROUP,
            _CFG_PHOTOS,
            PropertyType.String,
            "{}",
            "Hardware Hide device photos keyed by instance id.",
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



def _load_photos() -> dict[str, str]:
    _ensure_options()
    raw = str(config.Configuration().value(_CFG_SECTION, _CFG_GROUP, _CFG_PHOTOS) or "{}")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    return {str(k): str(v) for k, v in data.items() if k and v}


def _save_photos(rows: dict[str, str]) -> None:
    _ensure_options()
    try:
        config.Configuration().set(
            _CFG_SECTION, _CFG_GROUP, _CFG_PHOTOS, json.dumps(rows, ensure_ascii=True)
        )
    except Exception:
        pass


def _vid_pid(instance: str) -> tuple[int | None, int | None]:
    up = (instance or "").upper()
    vid = pid = None
    if "VID_" in up:
        try:
            vid = int(up.split("VID_", 1)[1][:4], 16)
        except ValueError:
            vid = None
    if "PID_" in up:
        try:
            pid = int(up.split("PID_", 1)[1][:4], 16)
        except ValueError:
            pid = None
    return vid, pid


def _dill_matches() -> list:
    try:
        from gremlin.device_initialization import joystick_devices
        return list(joystick_devices())
    except Exception:
        return []


def _photo_dir() -> Path:
    root = Path(sys.argv[0]).resolve().parent
    folder = root / "qml" / "maps" / "hidhide_photos"
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def _file_url(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.resolve().as_uri()


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


_snap_active = None
_snap_whitelist = None
_borrowed_active = False
_borrowed_whitelist = False
_session_ids: set[str] = set()


def snapshot_if_needed() -> None:
    global _snap_active, _snap_whitelist
    if not driver_present():
        return
    if _snap_active is None:
        _snap_active = get_active()
    if _snap_whitelist is None:
        _snap_whitelist = get_whitelist()


def restore_borrowed() -> None:
    """Undo cloak and whitelist we borrowed. Session hides die with the process."""
    global _snap_active, _snap_whitelist, _borrowed_active, _borrowed_whitelist
    if not driver_present():
        _session_ids.clear()
        return
    try:
        clear_session_hides()
    except Exception:
        pass
    try:
        if _borrowed_whitelist and _snap_whitelist is not None:
            set_whitelist(list(_snap_whitelist))
    except Exception:
        pass
    try:
        if _borrowed_active and _snap_active is not None:
            set_active(bool(_snap_active))
    except Exception:
        pass
    _borrowed_active = False
    _borrowed_whitelist = False
    _session_ids.clear()


def add_session_hides(ids: list[str]) -> bool:
    handle = _open_control()
    if handle is None:
        return False
    try:
        payload = _encode_multi_sz([i for i in ids if i])
        ok, _ = _ioctl(handle, IOCTL_ADD_SESSION_BLACKLIST, payload, 0)
        return ok
    finally:
        _close(handle)


def clear_session_hides() -> bool:
    handle = _open_control()
    if handle is None:
        return False
    try:
        ok, _ = _ioctl(handle, IOCTL_CLR_SESSION_BLACKLIST, None, 0)
        _session_ids.clear()
        return ok
    finally:
        _close(handle)


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



def list_hid_devices(gaming_only: bool = True) -> list[dict]:
    """HidHide Client method: HID interfaces, grouped by container, gaming filter on."""
    if os.name != "nt":
        return []
    try:
        return _list_hidhide_style(gaming_only)
    except Exception:
        return []


def _hid_guid():
    import ctypes
    hid = ctypes.WinDLL("hid")
    guid = (ctypes.c_ubyte * 16)()
    hid.HidD_GetHidGuid(ctypes.byref(guid))
    return guid


def _is_gaming(vid: int, pid: int, usage_page: int, usage: int) -> bool:
    if vid == 0x28DE and pid in (0x1142, 0x1205):
        return True
    if usage_page == 0x05:
        return True
    if usage_page == 0x01 and usage in (0x04, 0x05):
        return True
    return False


def _list_hidhide_style(gaming_only: bool) -> list[dict]:
    import ctypes
    from ctypes import wintypes

    setup = ctypes.WinDLL("setupapi", use_last_error=True)
    hid = ctypes.WinDLL("hid", use_last_error=True)
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)

    class GUID(ctypes.Structure):
        _fields_ = [
            ("Data1", wintypes.DWORD),
            ("Data2", wintypes.WORD),
            ("Data3", wintypes.WORD),
            ("Data4", ctypes.c_ubyte * 8),
        ]

    class SP_DEVINFO_DATA(ctypes.Structure):
        _fields_ = [
            ("cbSize", wintypes.DWORD),
            ("ClassGuid", GUID),
            ("DevInst", wintypes.DWORD),
            ("Reserved", ctypes.c_void_p),
        ]

    class SP_DEVICE_INTERFACE_DATA(ctypes.Structure):
        _fields_ = [
            ("cbSize", wintypes.DWORD),
            ("InterfaceClassGuid", GUID),
            ("Flags", wintypes.DWORD),
            ("Reserved", ctypes.c_void_p),
        ]

    class HIDD_ATTRIBUTES(ctypes.Structure):
        _fields_ = [
            ("Size", wintypes.ULONG),
            ("VendorID", wintypes.USHORT),
            ("ProductID", wintypes.USHORT),
            ("VersionNumber", wintypes.USHORT),
        ]

    class HIDP_CAPS(ctypes.Structure):
        _fields_ = [
            ("Usage", wintypes.USHORT),
            ("UsagePage", wintypes.USHORT),
            ("InputReportByteLength", wintypes.USHORT),
            ("OutputReportByteLength", wintypes.USHORT),
            ("FeatureReportByteLength", wintypes.USHORT),
            ("Reserved", wintypes.USHORT * 17),
            ("NumberLinkCollectionNodes", wintypes.USHORT),
            ("NumberInputButtonCaps", wintypes.USHORT),
            ("NumberInputValueCaps", wintypes.USHORT),
            ("NumberInputDataIndices", wintypes.USHORT),
            ("NumberOutputButtonCaps", wintypes.USHORT),
            ("NumberOutputValueCaps", wintypes.USHORT),
            ("NumberOutputDataIndices", wintypes.USHORT),
            ("NumberFeatureButtonCaps", wintypes.USHORT),
            ("NumberFeatureValueCaps", wintypes.USHORT),
            ("NumberFeatureDataIndices", wintypes.USHORT),
        ]

    hid_guid = GUID()
    hid.HidD_GetHidGuid(ctypes.byref(hid_guid))
    DIGCF_PRESENT = 0x00000002
    DIGCF_DEVICEINTERFACE = 0x00000010
    setup.SetupDiGetClassDevsW.restype = ctypes.c_void_p
    devs = setup.SetupDiGetClassDevsW(
        ctypes.byref(hid_guid), None, None, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE
    )
    if not devs or devs == ctypes.c_void_p(-1).value:
        return []

    groups: dict[str, dict] = {}
    try:
        index = 0
        while True:
            iface = SP_DEVICE_INTERFACE_DATA()
            iface.cbSize = ctypes.sizeof(SP_DEVICE_INTERFACE_DATA)
            if not setup.SetupDiEnumDeviceInterfaces(
                devs, None, ctypes.byref(hid_guid), index, ctypes.byref(iface)
            ):
                break
            index += 1
            needed = wintypes.DWORD(0)
            setup.SetupDiGetDeviceInterfaceDetailW(
                devs, ctypes.byref(iface), None, 0, ctypes.byref(needed), None
            )
            if needed.value < 8:
                continue
            detail = ctypes.create_string_buffer(needed.value)
            path_off = 8 if ctypes.sizeof(ctypes.c_void_p) == 8 else 6
            ctypes.c_dword.from_buffer(detail, 0).value = path_off
            info = SP_DEVINFO_DATA()
            info.cbSize = ctypes.sizeof(SP_DEVINFO_DATA)
            if not setup.SetupDiGetDeviceInterfaceDetailW(
                devs, ctypes.byref(iface), detail, needed, None, ctypes.byref(info)
            ):
                continue
            link = ctypes.wstring_at(ctypes.addressof(detail) + path_off)
            inst_buf = ctypes.create_unicode_buffer(512)
            if not setup.SetupDiGetDeviceInstanceIdW(devs, ctypes.byref(info), inst_buf, 512, None):
                continue
            instance = inst_buf.value
            if not instance or instance.upper().startswith("USB"):
                continue
            if not link or not link.startswith("\\"):
                continue
            handle = k32.CreateFileW(link, 0, 3, None, 3, 0, None)
            if handle == _INVALID or handle == -1:
                continue
            try:
                attrs = HIDD_ATTRIBUTES()
                attrs.Size = ctypes.sizeof(HIDD_ATTRIBUTES)
                vid = pid = 0
                if hid.HidD_GetAttributes(handle, ctypes.byref(attrs)):
                    vid = int(attrs.VendorID)
                    pid = int(attrs.ProductID)
                usage_page = usage = 0
                preparsed = ctypes.c_void_p()
                if hid.HidD_GetPreparsedData(handle, ctypes.byref(preparsed)) and preparsed:
                    caps = HIDP_CAPS()
                    hid.HidP_GetCaps(preparsed, ctypes.byref(caps))
                    usage_page = int(caps.UsagePage)
                    usage = int(caps.Usage)
                    hid.HidD_FreePreparsedData(preparsed)
                prod = ctypes.create_unicode_buffer(127)
                manu = ctypes.create_unicode_buffer(127)
                product = prod.value if hid.HidD_GetProductString(handle, prod, 254) else ""
                vendor = manu.value if hid.HidD_GetManufacturerString(handle, manu, 254) else ""
            finally:
                k32.CloseHandle(handle)
            desc_buf = ctypes.create_unicode_buffer(512)
            required = wintypes.DWORD(0)
            description = ""
            if setup.SetupDiGetDeviceRegistryPropertyW(
                devs,
                ctypes.byref(info),
                0,
                None,
                desc_buf,
                ctypes.sizeof(desc_buf),
                ctypes.byref(required),
            ):
                description = (desc_buf.value or "").strip()
            gaming = _is_gaming(vid, pid, usage_page, usage)
            if gaming_only and not gaming:
                continue
            container = _group_key(instance, vid, pid)
            name_parts = []
            for part in (vendor.strip(), product.strip()):
                if part and part not in name_parts:
                    name_parts.append(part)
            label = " ".join(name_parts).strip() or description or instance
            group = groups.setdefault(
                container,
                {
                    "instanceId": instance,
                    "instanceIds": [],
                    "name": label,
                    "canHide": True,
                    "photo": "",
                    "gaming": False,
                },
            )
            if instance not in group["instanceIds"]:
                group["instanceIds"].append(instance)
            group["gaming"] = group["gaming"] or gaming
            if label and (group["name"] == instance or len(label) > len(group["name"])):
                group["name"] = label
        out = list(groups.values())
        out.sort(key=lambda r: r["name"].lower())
        return out
    finally:
        setup.SetupDiDestroyDeviceInfoList(devs)



def _group_key(instance: str, vid: int | None = None, pid: int | None = None) -> str:
    """One row per physical device, same idea as HidHide base container."""
    cid = ""
    try:
        cid = _container_id(instance)
    except Exception:
        cid = ""
    if cid and "FFFFFFFFFFFF" not in cid.upper() and cid.upper() not in ("", "{00000000-0000-0000-0000-000000000000}"):
        return "cid:" + cid.upper()
    node = instance
    for _ in range(8):
        try:
            parent = _parent_instance(node)
        except Exception:
            parent = ""
        if not parent or parent.upper() == node.upper():
            break
        if parent.upper().startswith("USB\\VID_") or parent.upper().startswith("USB\VID_"):
            return "usb:" + parent.upper()
        node = parent
    if vid is not None:
        return f"vid:{vid:04X}"
    return "id:" + (instance or "").upper()


def _container_id(instance: str) -> str:
    try:
        text = _cm_property(instance, "8C7ED206-3F8A-4827-B3AB-AE9E1FAEFC6C", 2)
    except Exception:
        text = ""
    return text or ""


def _guid_le(text: str) -> bytes:
    import uuid
    u = uuid.UUID(text)
    return u.bytes_le[:4] + u.bytes_le[4:6] + u.bytes_le[6:8] + u.bytes[8:]


def _cm_property(instance: str, fmtid: str, pid: int) -> str:
    import ctypes
    from ctypes import wintypes

    cfg = ctypes.WinDLL("cfgmgr32", use_last_error=True)
    CR_SUCCESS = 0
    CR_BUFFER_SMALL = 26
    DEVPROP_TYPE_STRING = 0x00000012

    class DEVPROPKEY(ctypes.Structure):
        _fields_ = [("fmtid", ctypes.c_ubyte * 16), ("pid", wintypes.ULONG)]

    key = DEVPROPKEY()
    raw = _guid_le(fmtid)
    for i, b in enumerate(raw):
        key.fmtid[i] = b
    key.pid = pid
    devinst = wintypes.DWORD(0)
    if cfg.CM_Locate_DevNodeW(ctypes.byref(devinst), instance, 0) != CR_SUCCESS:
        return ""
    ptype = wintypes.ULONG(0)
    size = wintypes.ULONG(0)
    cfg.CM_Get_DevNode_PropertyW(
        devinst, ctypes.byref(key), ctypes.byref(ptype), None, ctypes.byref(size), 0
    )
    if size.value < 2:
        return ""
    buf = ctypes.create_unicode_buffer(max(2, size.value // 2))
    if cfg.CM_Get_DevNode_PropertyW(
        devinst, ctypes.byref(key), ctypes.byref(ptype), buf, ctypes.byref(size), 0
    ) != CR_SUCCESS:
        return ""
    return (buf.value or "").strip()


def _parent_instance(instance: str) -> str:
    import ctypes
    from ctypes import wintypes

    cfg = ctypes.WinDLL("cfgmgr32", use_last_error=True)
    CR_SUCCESS = 0
    devinst = wintypes.DWORD(0)
    parent = wintypes.DWORD(0)
    if cfg.CM_Locate_DevNodeW(ctypes.byref(devinst), instance, 0) != CR_SUCCESS:
        return ""
    if cfg.CM_Get_Parent(ctypes.byref(parent), devinst, 0) != CR_SUCCESS:
        return ""
    buf = ctypes.create_unicode_buffer(512)
    if cfg.CM_Get_Device_IDW(parent, buf, 512, 0) != CR_SUCCESS:
        return ""
    return buf.value or ""


def _friendly_name(instance: str) -> str:
    keys = [
        ("A45C254E-DF1C-4EFD-8020-67D146A850E0", 14),  # FriendlyName
        ("540B947E-8B40-45BC-A8A2-6A0B894E8B2D", 4),   # BusReportedDeviceDesc
        ("B725F130-47EF-101A-A5F1-02608C9EEBAC", 10),  # NAME
    ]
    for fmt, pid in keys:
        try:
            text = _cm_property(instance, fmt, pid)
        except Exception:
            text = ""
        if text and not text.upper().startswith("HID\\") and not text.upper().startswith("USB\\"):
            return text
    try:
        parent = _parent_instance(instance)
    except Exception:
        parent = ""
    if parent:
        for fmt, pid in keys:
            try:
                text = _cm_property(parent, fmt, pid)
            except Exception:
                text = ""
            if text and not text.upper().startswith("HID\\") and not text.upper().startswith("USB\\"):
                return text
    return ""


def _enrich_devices(rows: list[dict]) -> list[dict]:
    photos = _load_photos()
    dill_devs = _dill_matches()
    hw = None
    try:
        from gremlin.ui.hardware_profile import HardwareProfile
        hw = HardwareProfile()
    except Exception:
        hw = None
    for row in rows:
        instance = row["instanceId"]
        vid, pid = _vid_pid(instance)
        match = None
        same_vid = []
        if vid is not None:
            for dev in dill_devs:
                try:
                    dvid = int(dev.vendor_id)
                    dpid = int(dev.product_id)
                except Exception:
                    continue
                if dvid != vid:
                    continue
                same_vid.append(dev)
                if pid is not None and dpid == pid:
                    match = dev
                    break
        if match and match.name:
            row["name"] = match.name
        photo = photos.get(instance) or photos.get(instance.upper(), "")
        if photo:
            row["photo"] = _file_url(Path(photo)) if not str(photo).startswith("file:") else photo
        elif match and hw is not None:
            try:
                url = hw.profilePhotoUrl(match.name) or ""
                row["photo"] = url
            except Exception:
                row["photo"] = ""
        else:
            row["photo"] = row.get("photo") or ""
    return rows

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
        self._gaming_only = True
        _ensure_options()
        self.reload()

    def reload(self) -> None:
        self._present = driver_present()
        self._active = get_active() if self._present else False
        persistent = {i.upper() for i in get_blacklist()} if self._present else set()
        session = {i.upper() for i in _session_ids}
        hidden = persistent | session
        self._devices = []
        try:
            rows = list_hid_devices(self._gaming_only)
        except Exception:
            rows = []
        for row in _enrich_devices(rows):
            item = dict(row)
            item["hidden"] = item["instanceId"].upper() in hidden
            self._devices.append(item)
        if self._present:
            for hid in get_blacklist():
                if not hid or hid.upper().startswith("USB"):
                    continue
                if any(hid.upper() == str(x).upper() for d in self._devices for x in (d.get("instanceIds") or [d.get("instanceId")])):
                    continue
                named = {
                    "instanceId": hid,
                    "instanceIds": [hid],
                    "name": _friendly_name(hid) or hid,
                    "canHide": True,
                    "hidden": True,
                    "photo": "",
                }
                self._devices.extend(_enrich_devices([named]))
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

    @QtCore.Property(bool, notify=changed)
    def gamingOnly(self) -> bool:
        return self._gaming_only

    @QtCore.Slot(bool)
    def setGamingOnly(self, on: bool) -> None:
        self._gaming_only = bool(on)
        self.reload()

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
        global _borrowed_active
        snapshot_if_needed()
        self._ensure_gremlin_whitelisted()
        if not set_active(bool(on)):
            return False
        _borrowed_active = True
        self._active = bool(on)
        self.changed.emit()
        return True

    @QtCore.Slot(str, bool, result=bool)
    def setDeviceHidden(self, instance_id: str, hidden: bool) -> bool:
        if not self._present or not instance_id:
            return False
        snapshot_if_needed()
        group_ids = [instance_id]
        for row in self._devices:
            ids = row.get("instanceIds") or [row.get("instanceId")]
            if instance_id.upper() in {str(x).upper() for x in ids}:
                group_ids = [str(x) for x in ids if x]
                break
        drop = {x.upper() for x in group_ids}
        want = {i for i in _session_ids if i.upper() not in drop}
        if hidden:
            want.update(group_ids)
        if not clear_session_hides():
            return False
        if want and not add_session_hides(sorted(want)):
            return False
        _session_ids.clear()
        _session_ids.update(want)
        if hidden and not get_active():
            global _borrowed_active
            if set_active(True):
                _borrowed_active = True
                self._active = True
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

    @QtCore.Slot(str, str, result=bool)
    def setDevicePhoto(self, instance_id: str, path: str) -> bool:
        if not instance_id or not path:
            return False
        src = Path(path)
        if not src.is_file():
            # QML file url
            text = path
            if text.startswith("file:///"):
                text = text[8:]
            src = Path(text)
        if not src.is_file():
            return False
        dest = _photo_dir() / f"{abs(hash(instance_id)) & 0xFFFFFFFF:08x}{src.suffix.lower() or '.jpg'}"
        try:
            dest.write_bytes(src.read_bytes())
        except OSError:
            return False
        photos = _load_photos()
        photos[instance_id] = str(dest)
        _save_photos(photos)
        self.reload()
        return True

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
        global _borrowed_whitelist
        snapshot_if_needed()
        base = list(_snap_whitelist or [])
        wanted = {_gremlin_exe()}
        for row in self._games:
            wanted.add(row["path"])
        merged = []
        seen = set()
        for item in base + list(wanted):
            key = item.lower()
            if key in seen or not item:
                continue
            seen.add(key)
            merged.append(item)
        if set_whitelist(merged):
            _borrowed_whitelist = True
