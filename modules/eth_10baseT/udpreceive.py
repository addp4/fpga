#!/usr/bin/python3
import socket
import time

UDP_IP = "192.168.1.2"
UDP_PORT = 0x400

sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP
sock.bind((UDP_IP, UDP_PORT))
print("bind to", UDP_IP, UDP_PORT)
old_data = ''
count = 0
start_time = time.time()
packet_histograms = [0 for i in range(10)]
prev_slot = 0
packet_rate = 0
byte_rate = 0
# Minimum IPv4 frame size = 18 (Ethernet) + 20 (IPv4) + 8 (UDP) + 18 (payload) = 64 bytes
while True:
    data, addr = sock.recvfrom(0x1a) # buffer size is 1024 bytes
    if data != old_data:
        print("\nreceived message: %s" % data, "len=", len(data))
        old_data = data
        bytes_per_packet = (64-18) + len(data)
    count += 1
    elapsed = int(time.time() - start_time)
    slot = int(time.time() - start_time) % len(packet_histograms)
    if slot != prev_slot:
        packet_rate = packet_histograms[prev_slot]
        byte_rate = packet_rate * bytes_per_packet
        packet_histograms[slot] = 0
        prev_slot = slot
    else:
        packet_histograms[slot] += 1
    utilization = round(100 * ((byte_rate * 10) / 10_000_000))
    print(f"receive count: {count} sec={elapsed} pkt/s={packet_rate} bytes/s={byte_rate} utilization={utilization}%\r", end='')
