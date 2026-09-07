# -*- coding: utf-8; -*-

import ctypes
import os


def load_native_dll(path: str):
    """Load a DLL via LoadLibraryEx and wrap it as ctypes.CDLL.

    Avoids PyInstaller's ctypes hook (WinError 1114) and still exposes
    functions through a real _FuncPtr class.
    """
    path = os.path.abspath(path)
    directory = os.path.dirname(path)
    if hasattr(os, "add_dll_directory"):
        try:
            os.add_dll_directory(directory)
        except OSError:
            pass

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.LoadLibraryExW.restype = ctypes.c_void_p
    kernel32.LoadLibraryExW.argtypes = [
        ctypes.c_wchar_p,
        ctypes.c_void_p,
        ctypes.c_uint32,
    ]
    handle = kernel32.LoadLibraryExW(path, None, 0x00000008)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())

    class _NativeDLL(ctypes.CDLL):
        def __init__(self, name, h):
            self._name = name
            flags = self._func_flags_
            class _FuncPtr(ctypes._CFuncPtr):
                _flags_ = flags
                _restype_ = self._func_restype_
            self._FuncPtr = _FuncPtr
            self._handle = h

    return _NativeDLL(path, handle)
