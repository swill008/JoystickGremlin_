# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

from PySide6 import QtCore

from gremlin import event_handler
from gremlin.types import InputType
import gremlin.ui.type_aliases as ta
from gremlin.ui.input_pairing import _guid, _mapped_rows, _norm_if := None

QML_IMPORT_NAME = "Gremlin.Device"
QML_IMPORT_MAJOR_VERSION = 1
