"""Configuration, service controls and credential-free connection checks."""

from dataclasses import dataclass
import fcntl
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request


TARGET = "t3-ssh.target"
TUNNEL = "t3-mbp-tunnel.service"
TRAY = "t3-ssh-tray.service"
ASSETS = Path(__file__).parent.parent


@dataclass(frozen=True)
class Configuration:
    ssh_host: str
    local_port: int
    remote_port: int
    remote_os: str

    @property
    def local_url(self):
        return f"http://127.0.0.1:{self.local_port}"


def configuration():
    home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    raw = json.loads((home / "t3-ssh/config.json").read_text())
    return Configuration(**raw)


def directory():
    path = Path(os.environ["XDG_RUNTIME_DIR"]) / "t3-ssh"
    path.mkdir(mode=0o700, exist_ok=True)
    return path


def systemctl(*arguments):
    return subprocess.run(
        ["systemctl", "--user", *arguments],
        check=True, capture_output=True, text=True, timeout=20,
    ).stdout.strip()


def control(action):
    # A user pause/quit also consumes automatic startup for this login session.
    # Later app windows must not silently undo that choice.
    with (directory() / "launch.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        marker = directory() / "launched"
        # A graphical-session id also handles user managers that linger across
        # logout: the next desktop login should get its own first launch.
        session = systemctl("show", "graphical-session.target", "-p", "InvocationID", "--value")
        if action == "auto-start" and marker.exists() and marker.read_text() == session:
            return
        if action in ("start", "auto-start"):
            systemctl("--no-block", "start", TARGET, TUNNEL)
        elif action == "stop":
            systemctl("stop", TUNNEL)
        elif action == "quit":
            # A tray-spawned command is in the tray's cgroup and may itself be
            # stopped before systemctl returns. Preserve the choice first.
            marker.write_text(session)
            systemctl("stop", TARGET, TUNNEL, TRAY)
        else:
            raise ValueError(f"Unknown action: {action}")
        marker.write_text(session)


def service_state():
    output = systemctl("show", TUNNEL, "-p", "ActiveState", "-p", "SubState")
    return dict(line.split("=", 1) for line in output.splitlines() if "=" in line)


def snapshot():
    cfg = configuration()
    state = service_state()
    active = state.get("ActiveState") in ("active", "activating", "reloading")
    result = {
        "connected": False, "active": active, "url": cfg.local_url,
        "status": "Paused" if state.get("ActiveState") == "inactive" else "Connecting",
        "detail": "Start the connection to resume." if not active else "Waiting for T3 on the Mac.",
    }
    if not active:
        if state.get("ActiveState") != "inactive":
            result.update(status="Connection error", detail="Check t3-ssh logs and the Help instructions.")
        return result
    try:
        # Never consult the encrypted desktop catalog or read any credentials.
        # Bypass proxy variables: this endpoint must be reached through our loopback forward.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(cfg.local_url + "/.well-known/t3/environment", timeout=2) as response:
            descriptor = json.loads(response.read(65536))
        if (not isinstance(descriptor, dict) or not descriptor.get("environmentId")
                or not isinstance(descriptor.get("platform"), dict)
                or descriptor["platform"].get("os") != cfg.remote_os):
            raise ValueError("The forwarded address did not identify T3 on the expected operating system.")
        result.update(connected=True, status="Connected", detail=f"T3 on {descriptor.get('label') or cfg.ssh_host}")
    except (OSError, ValueError, urllib.error.URLError) as error:
        result.update(status="Connection error", detail=f"{error}. Check t3-ssh logs or Help.")
    return result


def describe(state):
    return f"{state['status']}\n{state['detail']}\nAddress: {state['url']}"


def help_file():
    cfg = configuration()
    text = (ASSETS / "help.txt").read_text()
    text = text.replace("@LOCAL_URL@", cfg.local_url).replace("@SSH_HOST@", cfg.ssh_host)
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "t3-ssh"
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = cache / "help.txt"
    path.write_text(text)
    return path
