#!/usr/bin/env python3
"""Local-only HA WebSocket protocol fixture; never contacts Home Assistant.

python3 scripts/websocket_fixture.py --advertise-host <LAN-IP>
Then package bsconfig.native-tests.json and run it on Roku. Ctrl-C removes
out/websocket-fixture.json. Only the public fixture address is packaged.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import socket
import socketserver
import struct
import threading
import time


TOKEN = "fixture-only"
SCENARIOS = {"success", "partial", "auth-rejected", "disconnect", "deadline"}


def exact(sock, count):
    result = bytearray()
    while len(result) < count:
        chunk = sock.recv(count - len(result))
        if not chunk:
            raise EOFError("client disconnected")
        result.extend(chunk)
    return bytes(result)


def frame(payload, opcode=1, final=True):
    prefix = bytes([(128 if final else 0) | opcode])
    if len(payload) < 126:
        return prefix + bytes([len(payload)]) + payload
    return prefix + b"\x7e" + struct.pack("!H", len(payload)) + payload


def receive(sock):
    first, second = exact(sock, 2)
    assert first & 128 and second & 128, "client frames must be final and masked"
    length = second & 127
    if length == 126:
        length = struct.unpack("!H", exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", exact(sock, 8))[0]
    assert length <= 65536, "oversized client frame"
    mask = exact(sock, 4)
    data = exact(sock, length)
    return first & 15, bytes(value ^ mask[index % 4] for index, value in enumerate(data))


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        scenario = "handshake"
        try:
            sock = self.request
            sock.settimeout(15)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            header = bytearray()
            while not header.endswith(b"\r\n\r\n"):
                header.extend(exact(sock, 1))
                assert len(header) <= 8192, "oversized upgrade"
            lines = header.decode("ascii").split("\r\n")
            method, path, version = lines[0].split()
            scenario = path.split("/")[1]
            assert scenario in SCENARIOS
            assert (method, path, version) == ("GET", f"/{scenario}/api/websocket", "HTTP/1.1")
            headers = dict(line.lower().split(":", 1) for line in lines[1:] if line)
            # Preserve the case-sensitive random handshake key.
            key = next(line.split(":", 1)[1].strip() for line in lines[1:] if line.lower().startswith("sec-websocket-key:"))
            assert headers["upgrade"].strip() == "websocket"
            accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
            upgrade = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n"

            def send(data):
                # Deliberately split writes; TCP may coalesce, so parser unit tests
                # separately guarantee incomplete-buffer coverage.
                if scenario == "partial":
                    for offset in range(0, len(data), 3):
                        sock.sendall(data[offset:offset + 3])
                        time.sleep(0.005)
                else:
                    sock.sendall(data)

            def message(value):
                send(frame(json.dumps(value).encode()))

            send(upgrade)
            message({"type": "auth_required", "ha_version": "fixture"})
            opcode, payload = receive(sock)
            assert opcode == 1 and json.loads(payload) == {"type": "auth", "access_token": TOKEN}, "unexpected auth"
            if scenario == "auth-rejected":
                message({"type": "auth_invalid", "message": "Fixture rejection"})
            else:
                message({"type": "auth_ok", "ha_version": "fixture"})
                opcode, payload = receive(sock)
                assert opcode == 1 and json.loads(payload) == {"id": 1, "type": "camera/stream", "entity_id": "camera.fixture", "format": "hls"}, "unexpected discovery"
                payload = json.dumps({"id": 1, "type": "result", "success": True, "result": {"url": "/api/hls/fixture/master_playlist.m3u8"}}).encode()
                if scenario in {"disconnect", "deadline"}:
                    sock.sendall(frame(payload)[:7])
                    if scenario == "deadline":
                        # Observe deadline-driven close; do not complete the response.
                        assert sock.recv(1) == b"", "expected client deadline close"
                    self.passed(scenario)
                    return
                if scenario == "partial":
                    send(frame(payload[:19], final=False))
                    send(frame(b"fixture-ping", opcode=9))
                    opcode, pong = receive(sock)
                    assert opcode == 10 and pong == b"fixture-ping", "missing masked pong"
                    send(frame(payload[19:], opcode=0))
                else:
                    send(frame(payload))
            opcode, payload = receive(sock)
            assert opcode == 8, "missing client close handshake"
            send(frame(payload, opcode=8))
            self.passed(scenario)
        except (AssertionError, EOFError, OSError, ValueError, KeyError, StopIteration) as error:
            # Never dump payloads or headers (even if a wrong client connects).
            print(f"FIXTURE_FAIL {scenario}: {type(error).__name__}", flush=True)

    def passed(self, scenario):
        with self.server.lock:
            self.server.passed.add(scenario)
            print(f"FIXTURE_PASS {scenario}", flush=True)
            if self.server.passed == SCENARIOS:
                print("WEBSOCKET_FIXTURE_PASSED", flush=True)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--advertise-host", required=True, help="This computer's IPv4 address reachable from Roku")
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    socket.inet_pton(socket.AF_INET, args.advertise_host)
    config = Path(__file__).resolve().parent.parent / "out" / "websocket-fixture.json"
    config.parent.mkdir(exist_ok=True)
    with Server((args.bind, args.port), Handler) as server:
        server.lock = threading.Lock()
        server.passed = set()
        # Refuse to overwrite an existing configuration owned by another run.
        with config.open("x") as output:
            json.dump({"url": f"http://{args.advertise_host}:{server.server_address[1]}"}, output)
        print("WEBSOCKET_FIXTURE_READY (synthetic token only)", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            config.unlink()


if __name__ == "__main__":
    main()
