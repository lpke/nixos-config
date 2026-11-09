"""Bounded local requests. systemd and the daemon's advisory lock arbitrate startup."""

import argparse
import json
import os
import socket
import subprocess
import sys
import time

from .paths import runtime_directory


def request(command, target=None):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(8)
        connection.connect(str(runtime_directory() / "controller.sock"))
        connection.sendall(json.dumps({"command": command, "target": target}).encode() + b"\n")
        response = b""
        while b"\n" not in response:
            chunk = connection.recv(65536)
            if not chunk or len(response) > 1024 * 1024:
                raise RuntimeError("Controller closed the request")
            response += chunk
        return json.loads(response.split(b"\n", 1)[0])


def main():
    parser = argparse.ArgumentParser(prog="monitor-control", description="Monitor control tray and blackout controller")
    parser.add_argument("command", nargs="?", default="launch",
                        choices=["launch", "toggle", "select", "label", "restore", "status", "quit"])
    parser.add_argument("target", nargs="?", help="Wayland output name or all; toggle defaults to saved hotkey monitor")
    args = parser.parse_args()
    if args.command == "select" and not args.target:
        parser.error("select requires an output name or all")
    try:
        try:
            result = request(args.command, args.target)
        except (FileNotFoundError, ConnectionRefusedError):
            if args.command in {"status", "restore", "quit"}:
                result = {"ok": True, "running": False, "blacked_out": []}
            else:
                subprocess.run(["systemctl", "--user", "start", "monitor-control.service"],
                               check=True, timeout=10, stdout=subprocess.DEVNULL)
                deadline = time.monotonic() + 5
                while True:
                    try:
                        result = request(args.command, args.target)
                        break
                    except (FileNotFoundError, ConnectionRefusedError):
                        if time.monotonic() >= deadline:
                            raise RuntimeError("Monitor control did not start")
                        time.sleep(0.05)
        if not result.get("ok"):
            raise RuntimeError(result.get("error", "Request failed"))
        if args.command == "status":
            print(json.dumps(result, indent=2))
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"monitor-control: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
