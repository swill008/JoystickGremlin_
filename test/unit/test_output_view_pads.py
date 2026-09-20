# -*- coding: utf-8; -*-
# SPDX-License-Identifier: GPL-3.0-only

from pathlib import Path

_QML = Path(__file__).resolve().parents[2] / "qml/OutputModuleView.qml"


def test_show_pads_checkbox_and_off_is_zero() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert 'text: "Show pads"' in text
    assert "padAOn" in text
    assert "padBOn" in text
    assert "v.padAX || 1" not in text
    assert "showPads !== false" in text


def test_save_toast_click_off_or_two_seconds() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert "id: _savedToast" in text
    assert "interval: 2000" in text
    assert "CloseOnPressOutside" in text
    assert "_savedToast.open()" in text


def test_button_columns_to_one_and_stacked_label() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert "from: 1; to: 16" in text
    assert "Math.max(1, _root.buttonColumns)" in text
    assert 'text: "Button"' in text


def test_show_meters_checkbox() -> None:
    text = _QML.read_text(encoding="utf-8")
    assert 'text: "Show meters"' in text
    assert "metersOn" in text
    assert "readonly property bool showMeters" not in text
