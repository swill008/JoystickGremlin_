# OSC sidecar (R15)

Proof-of-concept only. Not the GremlinEX OSC device tab.

## What it does

- UDP OSC listen on **9000** (avoids Companion on 8010 / 8000)
- `/streamdeck/1` with `1` / `0` presses vJoy device **1** button **1**

## Setup

```
python -m pip install python-osc pyvjoy
```

Installed Joystick Gremlin R15 profile must be **off** while this script runs.

```
python osc_listener.py
```

Other window:

```
python osc_send_test.py
```

## End goal

An OSC device tab inside R15 (like GremlinEX), mapped in the profile UI.
This folder stays until that exists.
