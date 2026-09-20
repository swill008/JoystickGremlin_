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
