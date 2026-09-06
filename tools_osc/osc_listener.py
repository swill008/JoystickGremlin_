"""OSC sidecar for Joystick Gremlin R15.

Listens on UDP 9000 (Companion/EX often occupy 8000/8001).
Maps /streamdeck/1 value 1/0 to vJoy device 1 button 1.

Run with the installed R15 profile OFF so this process can acquire vJoy.
"""
from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import BlockingOSCUDPServer
import pyvjoy

HOST = "0.0.0.0"
PORT = 9000
VJOY_ID = 1
BUTTON = 1

joy = pyvjoy.VJoyDevice(VJOY_ID)


def on_streamdeck(address, *args):
    pressed = bool(args and args[0])
    joy.set_button(BUTTON, int(pressed))
    print(
        f"{address} {args} -> vJoy{VJOY_ID} btn{BUTTON} "
        f"{'DOWN' if pressed else 'UP'}"
    )


if __name__ == "__main__":
    disp = Dispatcher()
    disp.map("/streamdeck/1", on_streamdeck)
    print(f"OSC {HOST}:{PORT} -> vJoy {VJOY_ID} button {BUTTON}")
    print("Gremlin profile OFF. Ctrl+C to stop.")
    BlockingOSCUDPServer((HOST, PORT), disp).serve_forever()
