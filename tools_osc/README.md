# OSC tools (Path B)

The sidecar is retired. Joystick Gremlin listens in-process.

- Tab: **OSC** next to Logical Device
- Listener: `gremlin/osc.py` (`OscRuntime`) binds UDP while a profile is **active**
- Default bind: `127.0.0.1:9000` (Options → Global → Osc)
- Incoming `/streamdeck/1` matches an OSC input with that address and fires the mapped actions (Map to vJoy, etc.)
- This process does **not** write vJoy itself

## Companion

Send OSC to `127.0.0.1:9000` with address `/streamdeck/1` and value `1` / `0`.

## Packet test without a Stream Deck

With Gremlin running from source and the profile **active**:

```
poetry run python tools_osc/osc_send_test.py
```

That sends `/streamdeck/1` 1 then 0. If that input is mapped to vJoy, the button should press and release.

Do not run `osc_listener.py` at the same time as Gremlin — both want port 9000, and the old sidecar stole vJoy.
