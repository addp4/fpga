#!/usr/bin/python3
import socket

UDP_IP = "192.168.1.2"
UDP_PORT = 0x400

sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP
sock.bind((UDP_IP, UDP_PORT))
print("bind to", UDP_IP, UDP_PORT)
while True:
    data, addr = sock.recvfrom(0x1a) # buffer size is 1024 bytes
    print("received message: %s" % data)
