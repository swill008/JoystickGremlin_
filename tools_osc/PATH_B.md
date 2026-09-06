# Path B — R15 look, EX OSC behavior

Locked 2026-09-06. Base is official R15 QML. OSC behavior is taken from GremlinEX, not the EX UI.

## Product

Same main window as R15:

- device strip across the top
- input list on the left
- Map to vJoy / actions on the right

New tab **OSC** next to **Logical Device**. Left list is user-defined OSC addresses (`/streamdeck/1`), not hardware. Right pane is the existing R15 `InputConfiguration` (remap, conditions, modes).

OSC is an **input device**. vJoy stays an **output action**. That is how EX works.

## EX runtime (what we copy)

```
UDP packet  → OscInterface  → match address  → Event as Button or Axis
        → profile actions  → vJoy
```

Button: first numeric arg != 0 = press, 0 = release.
Axis: first numeric arg is the axis value.

## R15 hooks we reuse

| R15 piece | Role for OSC |
|---|---|
| `qml/DeviceList.qml` | Add OSC tab like Keyboard / Logical Device |
| `qml/LogicalDevice.qml` | Template for left list + Add |
| `qml/Main.qml` | `currentTab === "osc"` shows OSC list; right pane already generic |
| `gremlin/logical_device.py` | Pattern for a fake device with a fixed GUID |
| existing Map to vJoy action | Output. Do not write vJoy inside the OSC listener |

## Build slices

1. **This folder** — sidecar + `gremlin/osc.py` listener (in-process ready).
2. **OSC device model** — GUID, address list, Button/Axis mode, profile XML.
3. **QML tab** — DeviceList + OscDevice.qml cloned from LogicalDevice.
4. **Event inject** — incoming OSC → R15 Event as joystick button/axis.
5. **Options** — enable, bind IP, port (default 9000).
6. Retire sidecar `osc_listener.py` writing vJoy directly.

Do not paste `gremlin/ui/osc_device.py` from EX. Different UI toolkit and event types.
