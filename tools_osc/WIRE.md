# Path B wiring

Applied on `feature/osc-streamdeck`. After you pull this branch, the remaining work is local run + Companion test — not more source edits.

What this commit wired:

1. `gremlin/code_runner.py` — `OscRuntime.start()` when a profile is activated, `stop()` when deactivated.
2. `joystick_gremlin.py` — OSC options (enabled / host / port) and listener stop on quit.
3. `gremlin/profile.py` — OSC addresses saved in the profile as `<osc-device><input>`.
4. `gremlin/ui/device.py` — OSC GUID treated like Logical Device (no DILL lookup).
5. `gremlin/event_handler.py` — OSC events labeled `OSC`, no missing-device warning.
6. `gremlin/ui/osc_device_model.py` — mapping pane shows the OSC address (`/streamdeck/1`).
7. `gremlin/ui/backend.py` — OSC device store reset on profile load.

UI tab + QML list were already on this branch (`qml/DeviceList.qml`, `qml/OscDevice.qml`, `qml/Main.qml`).
