# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import json

from PySide6 import QtCore, QtGui

from gremlin.config import Configuration
from gremlin.types import PropertyType
import gremlin.ui.type_aliases as ta

QML_IMPORT_NAME = "Gremlin.UI"
QML_IMPORT_MAJOR_VERSION = 1

SECTION = "global"
GROUP = "internal"
KEY_X = "window-x"
KEY_Y = "window-y"
KEY_W = "window-width"
KEY_H = "window-height"
KEY_MAX = "window-maximized"
KEY_MENU_W = "button-map-menu-width"
KEY_MENU_H = "button-map-menu-height"
KEY_DISPLAY_PANELS = "display-panels"
KEY_CLOSE_PANE = "close-pane-after-ok"
KEY_PANE_W = "action-pane-width"

DEFAULT_W = 1400
DEFAULT_H = 900
DEFAULT_MENU_W = 240
DEFAULT_MENU_H = 560


def _ensure() -> Configuration:
    cfg = Configuration()
    specs = (
        (KEY_X, PropertyType.Int, 0),
        (KEY_Y, PropertyType.Int, 0),
        (KEY_W, PropertyType.Int, DEFAULT_W),
        (KEY_H, PropertyType.Int, DEFAULT_H),
        (KEY_MAX, PropertyType.Bool, False),
        (KEY_MENU_W, PropertyType.Int, DEFAULT_MENU_W),
        (KEY_MENU_H, PropertyType.Int, DEFAULT_MENU_H),
        (KEY_DISPLAY_PANELS, PropertyType.String, "{}"),
        (KEY_CLOSE_PANE, PropertyType.Bool, False),
        (KEY_PANE_W, PropertyType.Int, 560),
    )
    for name, data_type, initial in specs:
        props = {"min": -100000, "max": 100000} if data_type == PropertyType.Int else {}
        value = cfg.value(SECTION, GROUP, name) if cfg.exists(SECTION, GROUP, name) else initial
        cfg.register(
            SECTION,
            GROUP,
            name,
            data_type,
            value,
            "Saved main window placement.",
            props,
            False,
        )
    return cfg


def _panel_key(kind: str, device_id: str) -> str:
    return f"{kind}|{device_id.strip().lower()}"


def _panel_map(cfg: Configuration) -> dict[str, bool]:
    raw = cfg.value(SECTION, GROUP, KEY_DISPLAY_PANELS) or "{}"
    try:
        data = json.loads(str(raw))
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    return {str(key): bool(value) for key, value in data.items()}


def display_panel_open(kind: str, device_id: str) -> bool:
    device = device_id.strip()
    if not device:
        return True
    saved = _panel_map(_ensure())
    key = _panel_key(kind, device)
    if key not in saved:
        return True
    return saved[key]


def set_display_panel_open(kind: str, device_id: str, open_panel: bool) -> None:
    device = device_id.strip()
    if not device:
        return
    cfg = _ensure()
    saved = _panel_map(cfg)
    saved[_panel_key(kind, device)] = bool(open_panel)
    cfg.set(SECTION, GROUP, KEY_DISPLAY_PANELS, json.dumps(saved, sort_keys=True))


def _available_screens() -> list[QtGui.QScreen]:
    app = QtGui.QGuiApplication.instance()
    if app is None:
        return []
    return list(app.screens())


def _screen_at(point: QtCore.QPoint) -> QtGui.QScreen | None:
    app = QtGui.QGuiApplication.instance()
    if app is None:
        return None
    return app.screenAt(point) or app.primaryScreen()


def _intersects_enough(rect: QtCore.QRect, screen: QtGui.QScreen) -> bool:
    visible = rect.intersected(screen.availableGeometry())
    if visible.width() < 200 or visible.height() < 80:
        return False
    return visible.width() * visible.height() >= 0.35 * rect.width() * rect.height()


def _target_screen(saved: QtCore.QRect) -> QtGui.QScreen | None:
    for screen in _available_screens():
        if _intersects_enough(saved, screen):
            return screen
    return _screen_at(QtGui.QCursor.pos())


def _centered(size: QtCore.QSize, screen: QtGui.QScreen) -> QtCore.QRect:
    avail = screen.availableGeometry()
    width = min(max(size.width(), 900), avail.width())
    height = min(max(size.height(), 600), avail.height())
    x = avail.x() + max(0, (avail.width() - width) // 2)
    y = avail.y() + max(0, (avail.height() - height) // 2)
    return QtCore.QRect(x, y, width, height)


def restore_window(window: QtGui.QWindow) -> None:
    cfg = _ensure()
    saved = QtCore.QRect(
        int(cfg.value(SECTION, GROUP, KEY_X)),
        int(cfg.value(SECTION, GROUP, KEY_Y)),
        int(cfg.value(SECTION, GROUP, KEY_W) or DEFAULT_W),
        int(cfg.value(SECTION, GROUP, KEY_H) or DEFAULT_H),
    )
    screen = _target_screen(saved)
    if screen is None:
        return
    fitted = _centered(saved.size(), screen)
    window.setVisibility(QtGui.QWindow.Visibility.Windowed)
    window.setGeometry(fitted)
    if cfg.value(SECTION, GROUP, KEY_MAX):
        window.setVisibility(QtGui.QWindow.Visibility.Maximized)


def save_window(window: QtGui.QWindow) -> None:
    cfg = _ensure()
    maximized = window.visibility() == QtGui.QWindow.Visibility.Maximized
    cfg.set(SECTION, GROUP, KEY_MAX, bool(maximized))
    if maximized:
        return
    cfg.set(SECTION, GROUP, KEY_X, int(window.x()))
    cfg.set(SECTION, GROUP, KEY_Y, int(window.y()))
    cfg.set(SECTION, GROUP, KEY_W, int(window.width()))
    cfg.set(SECTION, GROUP, KEY_H, int(window.height()))


@ta.QmlElement
class WindowPlacement(QtCore.QObject):
    def __init__(self, parent: ta.OQO = None) -> None:
        super().__init__(parent)
        _ensure()

    @QtCore.Slot(QtCore.QObject)
    def restore(self, window: QtCore.QObject) -> None:
        if window is None:
            return
        restore_window(window)

    @QtCore.Slot(QtCore.QObject)
    def save(self, window: QtCore.QObject) -> None:
        if window is None:
            return
        save_window(window)

    @QtCore.Slot(result=int)
    def buttonMapMenuWidth(self) -> int:
        cfg = _ensure()
        return int(cfg.value(SECTION, GROUP, KEY_MENU_W) or DEFAULT_MENU_W)

    @QtCore.Slot(result=int)
    def buttonMapMenuHeight(self) -> int:
        cfg = _ensure()
        return int(cfg.value(SECTION, GROUP, KEY_MENU_H) or DEFAULT_MENU_H)

    @QtCore.Slot(int, int)
    def saveButtonMapMenuSize(self, width: int, height: int) -> None:
        cfg = _ensure()
        cfg.set(SECTION, GROUP, KEY_MENU_W, max(180, min(900, int(width))))
        cfg.set(SECTION, GROUP, KEY_MENU_H, max(160, min(1000, int(height))))

    @QtCore.Slot(result=bool)
    def closePaneAfterOk(self) -> bool:
        cfg = _ensure()
        return bool(cfg.value(SECTION, GROUP, KEY_CLOSE_PANE))

    @QtCore.Slot(bool)
    def setClosePaneAfterOk(self, close_after: bool) -> None:
        cfg = _ensure()
        cfg.set(SECTION, GROUP, KEY_CLOSE_PANE, bool(close_after))

    @QtCore.Slot(result=int)
    def actionPaneWidth(self) -> int:
        cfg = _ensure()
        return max(420, min(1600, int(cfg.value(SECTION, GROUP, KEY_PANE_W) or 560)))

    @QtCore.Slot(int)
    def setActionPaneWidth(self, width: int) -> None:
        cfg = _ensure()
        cfg.set(SECTION, GROUP, KEY_PANE_W, max(420, min(1600, int(width))))

    @QtCore.Slot(str, str, result=bool)
    def displayPanelOpen(self, kind: str, device_id: str) -> bool:
        return display_panel_open(kind, device_id)

    @QtCore.Slot(str, str, bool)
    def setDisplayPanelOpen(self, kind: str, device_id: str, open_panel: bool) -> None:
        set_display_panel_open(kind, device_id, open_panel)
