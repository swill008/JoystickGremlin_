"""Retired sidecar.

Path B listens inside Joystick Gremlin (`gremlin.osc.OscRuntime`) on the
configured host/port (default 127.0.0.1:9000) while a profile is active.

This file used to write vJoy directly. Do not run it alongside Gremlin:
it will fight for port 9000 and steal vJoy device 1.

To send a test packet instead:

    poetry run python tools_osc/osc_send_test.py
"""

raise SystemExit(
    "Sidecar retired. Activate a Gremlin profile to listen on UDP 9000, "
    "or run tools_osc/osc_send_test.py to send a /streamdeck/1 pulse."
)
