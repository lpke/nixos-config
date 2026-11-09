"""Private configuration, scoped route controls and credential-free health."""

from dataclasses import dataclass
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import subprocess
import urllib.request
from urllib.parse import urlsplit
from uuid import UUID


TRAY = "t3-tray.service"
ASSETS = Path(__file__).parent.parent


@dataclass(frozen=True)
class Configuration:
    route: str
    url: str
    environment_id: str


def configuration():
    home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    raw = json.loads((home / "tailscale-config/t3-gateway.json").read_text())
    cfg = Configuration(**raw)
    network = ipaddress.ip_network(cfg.route, strict=True)
    url = urlsplit(cfg.url)
    if (network.version != 4 or network.prefixlen != 32
            or url.scheme not in ("http", "https") or url.hostname != str(network.network_address)
            or url.username or url.password or url.query or url.fragment
            or url.path not in ("", "/") or not url.port):
        raise ValueError("Expected a single IPv4 host route and its credential-free T3 URL.")
    UUID(cfg.environment_id)
    return cfg


def command(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=10).stdout.strip()


def tailscale_json(*args):
    result = subprocess.run(["tailscale", *args], capture_output=True, text=True, timeout=8)
    # status can return a nonzero exit code while still supplying useful JSON.
    try:
        value = json.loads(result.stdout)
    except ValueError as error:
        raise ValueError(result.stderr.strip() or "Cannot read Tailscale state.") from error
    if not isinstance(value, dict):
        raise ValueError("Unexpected Tailscale state response.")
    return value


def control(action):
    cfg = configuration()
    directory = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "t3-tailscale"
    directory.mkdir(mode=0o700, exist_ok=True)
    with (directory / "control.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        prefs = tailscale_json("debug", "prefs")
        routes = list(prefs.get("AdvertiseRoutes") or [])
        if action == "start":
            if tailscale_json("status", "--json").get("BackendState") != "Running":
                raise ValueError("Connect and sign in to Tailscale first. See t3-tailscale help.")
            if prefs.get("NoSNAT"):
                raise ValueError("Source NAT is disabled. See t3-tailscale help before changing shared preferences.")
            updated = routes if cfg.route in routes else [*routes, cfg.route]
        elif action in ("stop", "quit"):
            updated = [route for route in routes if route != cfg.route]
        else:
            raise ValueError(f"Unknown action: {action}")
        if updated != routes:
            command("tailscale", "set", "--advertise-routes=" + ",".join(updated))
        if action == "start":
            command("systemctl", "--user", "start", TRAY)
        # Quit is scoped to this route. The shared tray also controls SSH.


def forwarding_enabled():
    if Path("/proc/sys/net/ipv4/ip_forward").read_text().strip() != "1":
        return False
    try:
        return command("systemctl", "is-active", "nftables.service") == "active"
    except subprocess.CalledProcessError:
        return False


def snapshot():
    cfg = configuration()
    prefs = tailscale_json("debug", "prefs")
    status = tailscale_json("status", "--json")
    active = cfg.route in (prefs.get("AdvertiseRoutes") or [])
    result = {"connected": False, "active": active, "url": cfg.url, "route": cfg.route,
              "status": "Paused", "detail": "Start to advertise the T3 route again."}
    backend = status.get("BackendState")
    if backend != "Running":
        result.update(status="Tailscale disconnected", detail=f"Tailscale state: {backend}. Open Help to reconnect.")
        return result
    if not active:
        return result
    if cfg.route not in ((status.get("Self") or {}).get("PrimaryRoutes") or []):
        result.update(status="Approval needed", detail="Approve the T3 route on this PC in Tailscale Machines.")
        return result
    if not forwarding_enabled() or prefs.get("NoSNAT"):
        result.update(status="Gateway configuration error", detail="Forwarding and source NAT must be enabled. See Help.")
        return result
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(cfg.url.rstrip("/") + "/.well-known/t3/environment", timeout=2) as response:
            descriptor = json.loads(response.read(65536))
        if not isinstance(descriptor, dict) or descriptor.get("environmentId") != cfg.environment_id:
            raise ValueError("The address did not identify the configured Mac T3 environment.")
        result.update(connected=True, status="Connected", detail="Gateway ready; the configured Mac T3 environment responds.")
    except (OSError, ValueError) as error:
        result.update(status="Mac unavailable", detail=f"{error}. Check that the Mac is awake and T3 Network access is enabled.")
    return result


def describe(state):
    return f"{state['status']}\n{state['detail']}\nRoute: {state['route']}\nAddress: {state['url']}"


def help_file():
    try:
        cfg = configuration()
    except (OSError, ValueError, TypeError):
        cfg = Configuration("the configured T3 host route", "the configured Mac T3 URL", "")
    text = (ASSETS / "help.md").read_text().replace("@URL@", cfg.url).replace("@ROUTE@", cfg.route)
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "t3-tailscale"
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = cache / "help.md"
    path.write_text(text)
    path.chmod(0o600)
    return path
