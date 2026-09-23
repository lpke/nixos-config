"""Synergy process identity and screen changes. No network connections."""

import os
from pathlib import Path


def processes():
    found = {"synergy-core": [], "synergy-service": []}
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            name = (entry / "comm").read_text().strip()
            if name in found:
                # PID plus start time prevents PID reuse from reviving an old session.
                started = (entry / "stat").read_text().rsplit(")", 1)[1].split()[19]
                found[name].append((int(entry.name), started))
        except (OSError, IndexError):
            continue
    cores = sorted(found["synergy-core"])
    services = sorted(found["synergy-service"])
    session = (services or cores or [None])[0]
    return {"running": bool(cores), "session": list(session) if session else None,
            "cores": [list(core) for core in cores]}


class ScreenState:
    def __init__(self, local_screen):
        self.local_screen = local_screen
        self.role = None
        self.remote = False
        self.buffer = b""

    def feed(self, chunk):
        lines = (self.buffer + chunk).split(b"\n")
        self.buffer = lines.pop()
        for line in lines:
            self.process(line.decode(errors="replace"))

    def process(self, line):
        if "started server" in line:
            self.role, self.remote = "server", False
        elif "started client" in line:
            self.role, self.remote = "client", False
        elif any(marker in line for marker in (
            "stopped server", "stopped client", "server is dead", "process exited",
        )):
            self.remote = False
        elif self.role == "server" and ('switch from "' in line or 'jump from "' in line):
            marker = ' to "'
            if marker in line:
                destination = line.split(marker, 1)[1].split('"', 1)[0]
                self.remote = destination != self.local_screen
        elif self.role == "client":
            if "entering screen" in line:
                self.remote = False
            elif "leaving screen" in line:
                self.remote = True
