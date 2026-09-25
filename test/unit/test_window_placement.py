# -*- coding: utf-8; -*-
from pathlib import Path

_SRC = Path(__file__).resolve().parents[2] / "gremlin/ui/window_placement.py"


def test_restore_clamps_to_available_geometry() -> None:
    text = _SRC.read_text(encoding="utf-8")
    assert "def _fit_client" in text
    assert "frameMargins" in text
    assert "availableGeometry" in text
    assert "QtCore.QMargins(11, 45, 11, 11)" in text
    assert "window.setGeometry(fitted)" in text
    fit = text[text.find("def _fit_client") : text.find("def restore_window")]
    assert "(avail.width() - frame_w) // 2" in fit
    assert "(avail.height() - frame_h) // 2" in fit
    assert "margins.top()" in fit
    assert "saved.x()" not in fit
    # Maximized restore must not set a full-screen windowed rect first.
    restore = text[text.find("def restore_window") : text.find("def save_window")]
    assert "Visibility.Maximized" in restore
    assert restore.find("KEY_MAX") < restore.find("setGeometry")


def test_catalog_display_options_persist() -> None:
    text = _SRC.read_text(encoding="utf-8")
    assert 'KEY_CATALOG_PANEL = "catalog-display-options-open"' in text
    assert "def catalogPanelOpen" in text
    assert "def setCatalogPanelOpen" in text
    main = Path(__file__).resolve().parents[2] / "qml/Main.qml"
    qml = main.read_text(encoding="utf-8")
    assert "catalogPanel = _windowPlacement.catalogPanelOpen()" in qml
    assert "onCatalogPanelChanged: _windowPlacement.setCatalogPanelOpen(catalogPanel)" in qml
    close = qml[qml.find("function closeWorkRoom") : qml.find("function requestNewProfile")]
    assert "catalogPanel = false" not in close
