# OSC sidecar (R15)

Path B is locked. See [PATH_B.md](PATH_B.md).

This folder is the temporary sidecar until the OSC tab exists in R15.
The in-process listener lives at `gremlin/osc.py` (does **not** write vJoy).

## Sidecar (still needed until the tab ships)

- UDP OSC listen on **9000**
- `/streamdeck/1` with `1` / `0` presses vJoy device **1** button **1**
- Installed R15 profile must be **off** while `osc_listener.py` holds vJoy 1

```
python -m pip install python-osc pyvjoy
python osc_listener.py
```
