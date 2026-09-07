# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

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

DEFAULT_W = 1400
DEFAULT_H = 900
MARGIN = 24


def _ensure() -> Configuration:
    cfg = Configuration()
    specs = (
        (KEY_X, PropertyType.Int, 0),
        (KEY_Y, PropertyType.Int, 0),
        (KEY_W, PropertyType.Int, DEFAULT_W),
        (KEY_H, PropertyType.Int, DEFAULT_H),
        (KEY_MAX, PropertyType.Bool, False),
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


def _fit_to_screen(rect: QtCore.QRect, screen: QtGui.QScreen) -> QtCore.QRect:
    avail = screen.availableGeometry().adjusted(MARGIN, MARGIN, -MARGIN, -MARGIN)
    if avail.width() < 900 or avail.height() < 600:
        avail = screen.availableGeometry()
    width = min(max(rect.width(), 900), avail.width())
    height = min(max(rect.height(), 600), avail.height())
    x = min(max(rect.x(), avail.x()), avail.x() + avail.width() - width)
    y = min(max(rect.y(), avail.y()), avail.y() + avail.height() - height)
    return QtCore.QRect(x, y, width, height)


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
    if not _intersects_enough(saved, screen):
        avail = screen.availableGeometry()
        saved = QtCore.QRect(
            avail.x() + max(MARGIN, (avail.width() - DEFAULT_W) // 2),
            avail.y() + max(MARGIN, (avail.height() - DEFAULT_H) // 2),
            DEFAULT_W,
            DEFAULT_H,
        )
    fitted = _fit_to_screen(saved, screen)
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
