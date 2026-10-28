"""Runtime files and local control shared by the service, tray and command."""

import json
import os
from pathlib import Path
import socket


CONTROLLER_UNIT = "synergy-keys-controller.service"
TRAY_UNIT = "synergy-keys-tray.service"


def directory():
    path = Path(os.environ["XDG_RUNTIME_DIR"]) / "synergy-keys"
    path.mkdir(mode=0o700, exist_ok=True)
    return path


def read_json(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def write_json(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value) + "\n")
    temporary.replace(path)


def configuration():
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return json.loads((config_home / "synergy-keys/config.json").read_text())


def notify_service(message):
    address = os.environ.get("NOTIFY_SOCKET")
    if address:
        if address.startswith("@"):
            address = "\0" + address[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as client:
            client.sendto(message.encode(), address)


def request(command):
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(3)
        client.connect(str(directory() / "control.sock"))
        client.sendall((command + "\n").encode())
        data = b""
        while not data.endswith(b"\n"):
            chunk = client.recv(4096)
            if not chunk:
                raise OSError("Controller closed the connection")
            data += chunk
        return json.loads(data)


def describe(state):
    lines = [state.get("status", "Controller unavailable")]
    lines.append(f"Screen: {state.get('screen', 'unknown')}")
    lines.append("App shortcuts: handled locally on the Mac")
    lines.append(f"Mappings: {state.get('applied_mode') or 'pending'}")
    if state.get("error"):
        lines.append(state["error"])
    return "\n".join(lines)
