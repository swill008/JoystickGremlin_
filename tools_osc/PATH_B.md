# Path B — R15 look, EX OSC behavior

Locked 2026-09-06. Base is official R15 QML. OSC behavior is taken from GremlinEX, not the EX UI.

## Product

Same main window as R15:

- device strip across the top
- input list on the left
- Map to vJoy / actions on the right

New tab **OSC** next to **Logical Device**. Left list is user-defined OSC addresses (`/streamdeck/1`), not hardware. Right pane is the existing R15 `InputConfiguration` (remap, conditions, modes).

OSC is an **input device**. vJoy stays an **output action**. That is how EX works.

## Runtime

```
UDP packet  → OscListener  → OscRuntime  → match address  → Event as Button or Axis
        → profile actions  → vJoy
```

Button: first numeric arg != 0 = press, 0 = release.
Axis: first numeric arg is the axis value.

Listener starts in `CodeRunner.start()` and stops in `CodeRunner.stop()`.
Addresses persist in the profile as `<osc-device>` / `<input>`.

## Slices

1. Listener module — done (`gremlin/osc.py`)
2. OSC device model + profile XML — done
3. QML tab — done
4. Event inject — done
5. Options (enable / host / port) — done
6. Sidecar retired for in-app use — `tools_osc/osc_listener.py` remains as a standalone tester only
