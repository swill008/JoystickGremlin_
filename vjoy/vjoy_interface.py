# -*- coding: utf-8; -*-

# SPDX-License-Identifier: GPL-3.0-only

import ctypes
import enum
import os
import sys

from gremlin.error import GremlinError
from gremlin.win_dll import load_native_dll


class VJoyState(enum.Enum):
    """Enumeration of the possible VJoy device states."""

    Owned = 0
    Free = 1
    Bust = 2
    Missing = 3
    Unknown = 4


class VJoyInterface:
    """Allows low level interaction with VJoy devices via ctypes."""

    dev_path = os.path.join(os.path.dirname(__file__), "vJoyInterface.dll")
    if os.path.isfile("vJoyInterface.dll"):
        dll_path = os.path.abspath("vJoyInterface.dll")
    elif getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS") and os.path.isfile(
        os.path.join(sys._MEIPASS, "vJoyInterface.dll")
    ):
        dll_path = os.path.join(sys._MEIPASS, "vJoyInterface.dll")
    elif os.path.isfile(dev_path):
        dll_path = dev_path
    else:
        raise GremlinError("Unable to locate vjoy dll")

    vjoy_dll_loaded = False
    try:
        vjoy_dll = load_native_dll(dll_path)
        vjoy_dll_loaded = True
    except OSError as e:
        print("Failed loading vJoy dll, {}".format(e))

    api_functions = {
        "GetvJoyVersion": {"arguments": [], "returns": ctypes.c_short},
        "vJoyEnabled": {"arguments": [], "returns": ctypes.c_bool},
        "GetvJoyProductString": {"arguments": [], "returns": ctypes.c_wchar_p},
        "GetvJoyManufacturerString": {"arguments": [], "returns": ctypes.c_wchar_p},
        "GetvJoySerialNumberString": {"arguments": [], "returns": ctypes.c_wchar_p},
        "GetVJDButtonNumber": {"arguments": [ctypes.c_uint], "returns": ctypes.c_int},
        "GetVJDDiscPovNumber": {"arguments": [ctypes.c_uint], "returns": ctypes.c_int},
        "GetVJDContPovNumber": {"arguments": [ctypes.c_uint], "returns": ctypes.c_int},
        "GetVJDAxisExist": {
            "arguments": [ctypes.c_uint, ctypes.c_uint],
            "returns": ctypes.c_int,
        },
        "GetVJDAxisMax": {
            "arguments": [ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p],
            "returns": ctypes.c_bool,
        },
        "GetVJDAxisMin": {
            "arguments": [ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p],
            "returns": ctypes.c_bool,
        },
        "GetOwnerPid": {"arguments": [ctypes.c_uint], "returns": ctypes.c_int},
        "AcquireVJD": {"arguments": [ctypes.c_uint], "returns": ctypes.c_bool},
        "RelinquishVJD": {
            "arguments": [ctypes.c_uint],
            "returns": None,
        },
        "UpdateVJD": {
            "arguments": [ctypes.c_uint, ctypes.c_void_p],
            "returns": ctypes.c_bool,
        },
        "GetVJDStatus": {"arguments": [ctypes.c_uint], "returns": ctypes.c_int},
        "ResetVJD": {"arguments": [ctypes.c_uint], "returns": ctypes.c_bool},
        "ResetAll": {"arguments": [], "returns": None},
        "ResetButtons": {"arguments": [ctypes.c_uint], "returns": ctypes.c_bool},
        "ResetPovs": {"arguments": [ctypes.c_uint], "returns": ctypes.c_bool},
        "SetAxis": {
            "arguments": [ctypes.c_long, ctypes.c_uint, ctypes.c_uint],
            "returns": ctypes.c_bool,
        },
        "SetBtn": {
            "arguments": [ctypes.c_bool, ctypes.c_uint, ctypes.c_ubyte],
            "returns": ctypes.c_bool,
        },
        "SetDiscPov": {
            "arguments": [ctypes.c_int, ctypes.c_uint, ctypes.c_ubyte],
            "returns": ctypes.c_bool,
        },
        "SetContPov": {
            "arguments": [ctypes.c_ulong, ctypes.c_uint, ctypes.c_ubyte],
            "returns": ctypes.c_bool,
        },
    }

    @classmethod
    def initialize(cls) -> None:
        if not cls.vjoy_dll_loaded:
            return

        for fn_name, params in cls.api_functions.items():
            dll_fn = getattr(cls.vjoy_dll, fn_name)
            if "arguments" in params:
                dll_fn.argtypes = params["arguments"]
            if "returns" in params:
                dll_fn.restype = params["returns"]
            setattr(cls, fn_name, dll_fn)


VJoyInterface.initialize()
