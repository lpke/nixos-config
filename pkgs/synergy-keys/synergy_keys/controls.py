"""Independent keyboard and sharing controls, using Synergy's native tray API."""

import fcntl
import json
import os
from pathlib import Path
import subprocess
import time

from . import synergy
from .runtime import CONTROLLER_UNIT, TRAY_UNIT, directory, read_json, write_json


NATIVE_ID = "tray-icon tray app"
NATIVE_TITLE = "synergy-tray"


class MenuUnavailable(OSError):
    """Synergy has no registered native tray backend."""


def preferences_path():
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "synergy-keys/controls.json"


def preferences():
    return read_json(preferences_path())


def set_preference(key, value):
    path = preferences_path()
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    state = preferences()
    state[key] = value
    write_json(path, state)


def command(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=10).stdout.strip()


def bus(*args):
    return json.loads(command("busctl", "--user", "--json=short", "--", *args))["data"]


def native_menu():
    items = bus("get-property", "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
                "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
    for item in items:
        destination, path = item.split("/", 1)
        path = "/" + path
        try:
            identity = bus("get-property", destination, path, "org.kde.StatusNotifierItem", "Id")
            if identity != NATIVE_ID:
                continue
            title = bus("get-property", destination, path, "org.kde.StatusNotifierItem", "Title")
            if title == NATIVE_TITLE:
                return destination, bus("get-property", destination, path, "org.kde.StatusNotifierItem", "Menu")
        except (subprocess.SubprocessError, ValueError, KeyError):
            continue  # Items can disappear while the tray is being inspected.
    raise MenuUnavailable("Synergy's native control menu is unavailable. Start Synergy or check its logs.")


def menu_entries(layout):
    identity, properties, children = layout
    if "label" in properties and properties.get("enabled", {}).get("data", True):
        yield identity, properties["label"]["data"]
    for child in children:
        yield from menu_entries(child["data"])


def native_action(label):
    try:
        _native_action(label)
    except (ValueError, KeyError, TypeError, IndexError) as error:
        raise OSError("Synergy's native menu protocol changed. Check its configuration and logs.") from error


def _native_action(label):
    destination, path = native_menu()
    layout = bus("call", destination, path, "com.canonical.dbusmenu", "GetLayout", "iias", "0", "-1", "0")
    for identity, text in menu_entries(layout[1]):
        if text == label:
            command("busctl", "--user", "call", destination, path, "com.canonical.dbusmenu",
                    "Event", "isvu", str(identity), "clicked", "i", "0", "0")
            return
    raise OSError(f"Synergy's native menu does not offer {label!r}.")


def wait_running(wanted, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if synergy.processes()["running"] == wanted:
            return
        time.sleep(.1)
    raise OSError("Synergy did not reach the requested sharing state. Check Synergy configuration and logs.")


def start_controller():
    try:
        command("systemctl", "--user", "reset-failed", CONTROLLER_UNIT)
    except subprocess.CalledProcessError:
        # Stopped units can be garbage-collected by systemd. Start loads the
        # installed unit again; reset-failed has nothing to clear in that case.
        pass
    command("systemctl", "--user", "start", CONTROLLER_UNIT)


def keys(action):
    paused = action == "pause"
    if action not in ("pause", "resume"):
        raise ValueError(f"Unknown synergy-keys action: {action}")
    old = preferences().get("keys_paused", False)
    set_preference("keys_paused", paused)
    try:
        if paused:
            command("systemctl", "--user", "stop", CONTROLLER_UNIT)
        elif synergy.processes()["running"] and not preferences().get("synergy_paused", False):
            start_controller()
    except (OSError, subprocess.SubprocessError):
        set_preference("keys_paused", old)
        raise


def sharing(action):
    if action == 'launch':
        # Explicit app launch also loads an installed tray update.
        command('systemctl', '--user', 'restart', TRAY_UNIT)
        action = 'resume'
    if action == 'tray':
        command('systemctl', '--user', 'start', TRAY_UNIT)
        return
    if action == 'quit':
        # Set sharing's pause before stopping anything so the tray cannot rearm keys.
        set_preference('synergy_paused', True)
        command('systemctl', '--user', 'stop', CONTROLLER_UNIT)
        if 'com.symless.synergy' in command('flatpak', 'ps', '--columns=application').splitlines():
            try:
                command('flatpak', 'kill', 'com.symless.synergy')
            except subprocess.CalledProcessError:
                if 'com.symless.synergy' in command('flatpak', 'ps', '--columns=application').splitlines():
                    raise
        # A tray action runs in this unit's cgroup. Queue its stop, then return.
        command('systemctl', '--user', '--no-block', 'stop', TRAY_UNIT)
        return
    if action == "config":
        native_action("Show config")
        return
    if action not in ("pause", "resume"):
        raise ValueError(f"Unknown Synergy action: {action}")
    wanted = action == "resume"
    old = preferences().get("synergy_paused", False)
    set_preference("synergy_paused", not wanted)
    try:
        running = synergy.processes()["running"]
        if wanted and not running:
            try:
                native_action("Start")
            except MenuUnavailable:
                # Recover a completely closed Flatpak without killing its GUI or
                # starting a second unmanaged core process ourselves.
                command("flatpak", "run", "--command=/app/lib/com.symless.synergy/synergy-service",
                        "com.symless.synergy", "-d")
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline:
                    if synergy.processes()["running"]:
                        break
                    try:
                        native_action("Start")
                        break
                    except MenuUnavailable:
                        time.sleep(.2)
        elif not wanted and running:
            native_action("Stop")
        wait_running(wanted)
    except (OSError, subprocess.SubprocessError):
        set_preference("synergy_paused", old)
        raise


def control(target, action):
    if target not in ("synergy", "keys"):
        raise ValueError(f"Unknown control target: {target}")
    with (directory() / "actions.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        (sharing if target == "synergy" else keys)(action)
