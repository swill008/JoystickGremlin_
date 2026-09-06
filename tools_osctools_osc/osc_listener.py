from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import BlockingOSCUDPServer

HOST = "0.0.0.0"
PORT = 9000

def on_any(address, *args):
    print(f"{address}  {args}")

if __name__ == "__main__":
    disp = Dispatcher()
    disp.set_default_handler(on_any)
    print(f"OSC listener on {HOST}:{PORT}")
    print("Leave this window open. Ctrl+C to stop.")
    BlockingOSCUDPServer((HOST, PORT), disp).serve_forever()