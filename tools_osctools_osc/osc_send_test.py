from pythonosc.udp_client import SimpleUDPClient

client = SimpleUDPClient("127.0.0.1", 9000)
client.send_message("/streamdeck/1", 1)
client.send_message("/streamdeck/1", 0)
print("Sent /streamdeck/1 1 then 0 to 127.0.0.1:8000")