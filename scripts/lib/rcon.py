#!/usr/bin/env python3
"""Minimal Minecraft RCON client for controlled automation.

This helper is intentionally small and standard-library only. It supports
authenticate, command execution, and graceful disconnect.
"""

from __future__ import annotations

import argparse
import socket
import struct
import sys


PACKET_TYPE_COMMAND = 2
PACKET_TYPE_LOGIN = 3
PACKET_TYPE_RESPONSE = 0


def _send_packet(sock: socket.socket, packet_id: int, packet_type: int, payload: str) -> None:
    data = payload.encode("utf-8") + b"\x00\x00"
    length = struct.pack("<i", len(data) + 8)
    body = struct.pack("<ii", packet_id, packet_type) + data
    sock.sendall(length + body)


def _recv_exact(sock: socket.socket, size: int) -> bytes:
    chunks = []
    remaining = size
    while remaining > 0:
        chunk = sock.recv(remaining)
        if not chunk:
            raise RuntimeError("RCON connection closed unexpectedly")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def _recv_packet(sock: socket.socket) -> tuple[int, int, str]:
    length = struct.unpack("<i", _recv_exact(sock, 4))[0]
    body = _recv_exact(sock, length)
    packet_id, packet_type = struct.unpack("<ii", body[:8])
    payload = body[8:-2].decode("utf-8", errors="replace")
    return packet_id, packet_type, payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Minecraft RCON client")
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--password", required=True)
    parser.add_argument("--command", required=True)
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()

    with socket.create_connection((args.host, args.port), timeout=args.timeout) as sock:
        _send_packet(sock, 1, PACKET_TYPE_LOGIN, args.password)
        packet_id, packet_type, _ = _recv_packet(sock)
        if packet_id == -1:
            raise RuntimeError("RCON authentication failed")

        _send_packet(sock, 2, PACKET_TYPE_COMMAND, args.command)
        _, _, response = _recv_packet(sock)
        if response:
            sys.stdout.write(response)
            if not response.endswith("\n"):
                sys.stdout.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

