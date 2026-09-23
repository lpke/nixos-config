import asyncio
import os
from pathlib import Path


DEVICE = "ydotoold virtual device"
KEYCODES = {"local": 192, "mac": 194, "synergy-terminal": 191}


def selected_mode(remote, application, terminal_applications):
    if not remote:
        return "local"
    if application is None or application in terminal_applications:
        return "synergy-terminal"
    return "mac"


def captures_mode_device():
    paths = set()
    for event in Path("/sys/class/input").glob("event*"):
        try:
            if (event / "device/name").read_text().strip() == DEVICE:
                paths.add(f"/dev/input/{event.name}")
        except OSError:
            continue
    if not paths:
        return False
    for process in Path("/proc").iterdir():
        if not process.name.isdigit():
            continue
        try:
            if process.stat().st_uid != os.getuid():
                continue
            if (process / "comm").read_text().strip() != "xremap":
                continue
            for descriptor in (process / "fd").iterdir():
                try:
                    if os.readlink(descriptor) in paths:
                        return True
                except OSError:
                    continue
        except OSError:
            continue
    return False


async def apply(mode):
    if not captures_mode_device():
        raise OSError("xremap is not reading the mode-switch device")
    keycode = KEYCODES[mode]
    process = await asyncio.create_subprocess_exec(
        "ydotool", "key", f"{keycode}:1", f"{keycode}:0",
        stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE,
    )
    try:
        _, error = await asyncio.wait_for(process.communicate(), 2)
    finally:
        if process.returncode is None:
            process.kill()
            await process.wait()
    if process.returncode:
        raise OSError(error.decode(errors="replace").strip() or "Mode switch failed")
