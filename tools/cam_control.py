#!/usr/bin/env python3
"""
Sterowanie ESP cam (AP ESP_VIDEO_TX) przez UDP :1234.

Przyklady (PC polaczony z WiFi ESP_VIDEO_TX, haslo video_stream):
  python tools/cam_control.py led 1
  python tools/cam_control.py led 0x0F
  python tools/cam_control.py start
  python tools/cam_control.py stop
"""
from __future__ import annotations

import argparse
import socket
import sys

DEFAULT_HOST = "192.168.4.1"
DEFAULT_PORT = 1234


def send_text(host: str, port: int, msg: str) -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(msg.encode("ascii"), (host, port))
        print(f"UDP -> {host}:{port}  {msg!r}")
    finally:
        sock.close()


def send_byte(host: str, port: int, value: int) -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(bytes([value & 0xFF]), (host, port))
        print(f"UDP -> {host}:{port}  byte=0x{value & 0xFF:02X}")
    finally:
        sock.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="UDP do ESP cam (wideo + LED Basys)")
    parser.add_argument("cmd", choices=("start", "stop", "led"))
    parser.add_argument("value", nargs="?", default="0",
                        help="dla led: 0-15 lub 0x.. (bity LD4..LD1)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    if args.cmd == "start":
        send_text(args.host, args.port, "start")
    elif args.cmd == "stop":
        send_text(args.host, args.port, "stop")
    else:
        v = int(args.value, 0)
        send_byte(args.host, args.port, v)
    return 0


if __name__ == "__main__":
    sys.exit(main())
