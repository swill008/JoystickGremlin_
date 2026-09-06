# Path B OSC (Stream Deck via Companion)

This folder is the standalone tester used before the in-app tab existed.

For daily use, run Joystick Gremlin **from this clone / this branch**, not the installed R15 exe.

## Run Gremlin from source

In the repo root (not this folder):

```
python -m pip install python-osc
python joystick_gremlin.py
```

You should see an **OSC** tab next to **Logical Device**.

## Map a Stream Deck key

1. OSC tab → type Button → Add.
2. Rename the new input to the Companion address, e.g. `/streamdeck/1`.
3. On the right, add **Map to vJoy** the same way you would for a joystick button.
4. Tools → Options → osc: host `127.0.0.1`, port `9000`, enabled on.
5. Activate the profile (power icon). Companion must send to `127.0.0.1:9000`.
6. Keep Gremlin profile ON. Do not also run `osc_listener.py` on port 9000 at the same time.

## Standalone tester (profile OFF)

```
python osc_listener.py
python osc_send_test.py
```

That path talks to vJoy directly and will fight Gremlin if both own the same vJoy device.
