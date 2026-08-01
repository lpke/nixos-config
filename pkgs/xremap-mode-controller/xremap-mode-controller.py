#!/usr/bin/env python3

import argparse
import asyncio
import logging
import os
from pathlib import Path
import signal

from dbus_next import BusType, Message, MessageType
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method


SERVICE_NAME = "dev.luke.XremapModeController"
OBJECT_PATH = "/dev/luke/XremapModeController"
INTERFACE_NAME = SERVICE_NAME
KWIN_SERVICE = "org.kde.KWin"
SCRIPT_NAME = "xremap-mode-controller"
MODE_INPUT_DEVICE = "ydotoold virtual device"


class SynergyState:
    def __init__(self, local_screen):
        self.local_screen = local_screen
        self.role = None
        self.remote = False

    def reset(self):
        self.role = None
        self.remote = False

    def process(self, line):
        previous = self.remote

        if "started server" in line:
            self.role = "server"
            self.remote = False
        elif "started client" in line:
            self.role = "client"
            self.remote = False
        elif any(
            marker in line
            for marker in (
                "stopped server",
                "stopped client",
                "server is dead",
                "process exited",
            )
        ):
            self.remote = False
        elif self.role == "server" and (
            'switch from "' in line or 'jump from "' in line
        ):
            destination = self._destination(line)
            if destination is not None:
                self.remote = destination != self.local_screen
        elif self.role == "client":
            if "entering screen" in line:
                self.remote = False
            elif "leaving screen" in line:
                self.remote = True

        return previous != self.remote

    @staticmethod
    def _destination(line):
        marker = ' to "'
        start = line.find(marker)
        if start == -1:
            return None
        start += len(marker)
        end = line.find('"', start)
        return None if end == -1 else line[start:end]


class ModeControllerInterface(ServiceInterface):
    def __init__(self, controller):
        super().__init__(INTERFACE_NAME)
        self.controller = controller

    @method()
    def SetActiveWindow(
        self,
        caption: "s",
        resource_class: "s",
        resource_name: "s",
    ):
        del caption
        identifiers = {resource_class.casefold(), resource_name.casefold()}
        asyncio.create_task(self.controller.set_vnc("vncviewer" in identifiers))


class ModeController:
    def __init__(self, args):
        self.args = args
        self.bus = None
        self.dbus = None
        self.synergy_alive = synergy_running()
        self.synergy_remote = False
        self.vnc_active = False
        self.applied_mode = None
        self.reconcile_event = asyncio.Event()
        self.kwin_lock = asyncio.Lock()
        self.kwin_script_id = None
        self.last_apply_error = None

    @property
    def desired_mode(self):
        if self.vnc_active or (self.synergy_alive and self.synergy_remote):
            return "mac"
        return "local"

    async def attach_bus(self, bus):
        self.bus = bus
        introspection = await bus.introspect(
            "org.freedesktop.DBus", "/org/freedesktop/DBus"
        )
        proxy = bus.get_proxy_object(
            "org.freedesktop.DBus", "/org/freedesktop/DBus", introspection
        )
        self.dbus = proxy.get_interface("org.freedesktop.DBus")
        self.dbus.on_name_owner_changed(self._name_owner_changed)

    async def set_vnc(self, active):
        if self.vnc_active == active:
            return
        self.vnc_active = active
        logging.info("TigerVNC: %s", "active" if active else "inactive")
        self.write_state()
        self.request_reconcile()

    async def set_synergy_alive(self, alive):
        if self.synergy_alive == alive:
            return
        if alive:
            # Never reuse a remote state left by a crashed previous core process.
            self.synergy_remote = False
        self.synergy_alive = alive
        logging.info("Synergy: %s", "running" if alive else "stopped")
        self.write_state()
        self.request_reconcile()

    async def set_synergy_remote(self, remote):
        if self.synergy_remote == remote:
            return
        self.synergy_remote = remote
        logging.info("Synergy screen: %s", "remote" if remote else "local")
        self.write_state()
        self.request_reconcile()

    def request_reconcile(self, force=False):
        if force:
            self.applied_mode = None
        self.reconcile_event.set()

    async def reconcile_forever(self):
        while True:
            await self.reconcile_event.wait()
            self.reconcile_event.clear()
            while self.applied_mode != self.desired_mode:
                desired = self.desired_mode
                if not xremap_captures_device(MODE_INPUT_DEVICE):
                    self._log_apply_error(
                        f'xremap has not grabbed "{MODE_INPUT_DEVICE}"'
                    )
                    await asyncio.sleep(0.5)
                    continue

                keycode = (
                    self.args.mac_keycode
                    if desired == "mac"
                    else self.args.local_keycode
                )
                process = None
                try:
                    process = await asyncio.create_subprocess_exec(
                        self.args.ydotool,
                        "key",
                        f"{keycode}:1",
                        f"{keycode}:0",
                        stdout=asyncio.subprocess.DEVNULL,
                        stderr=asyncio.subprocess.PIPE,
                    )
                    _, stderr = await asyncio.wait_for(process.communicate(), timeout=2)
                except asyncio.TimeoutError:
                    process.kill()
                    await process.wait()
                    self._log_apply_error("ydotool timed out")
                    await asyncio.sleep(0.5)
                    continue
                except OSError as error:
                    self._log_apply_error(str(error))
                    await asyncio.sleep(0.5)
                    continue

                if process.returncode != 0:
                    message = stderr.decode(errors="replace").strip()
                    self._log_apply_error(
                        message or f"ydotool exited with {process.returncode}"
                    )
                    await asyncio.sleep(0.5)
                    continue

                self.last_apply_error = None
                self.applied_mode = desired
                logging.info("xremap mode: %s", desired)
                self.write_state()

    def _log_apply_error(self, message):
        if message != self.last_apply_error:
            logging.warning("Cannot set xremap mode: %s; retrying", message)
            self.last_apply_error = message

    def write_state(self):
        path = Path(self.args.state_file)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(f".{path.name}.tmp")
        temporary.write_text(
            "\n".join(
                (
                    f"desired_mode={self.desired_mode}",
                    f"applied_mode={self.applied_mode or 'pending'}",
                    f"tigervnc={'active' if self.vnc_active else 'inactive'}",
                    f"synergy={'remote' if self.synergy_remote else 'local'}",
                    f"synergy_process={'running' if self.synergy_alive else 'stopped'}",
                    "",
                )
            )
        )
        os.replace(temporary, path)

    async def install_kwin_script(self):
        async with self.kwin_lock:
            if not await self.dbus.call_name_has_owner(KWIN_SERVICE):
                return

            await self._unload_kwin_script()
            reply = await self._call(
                Message(
                    destination=KWIN_SERVICE,
                    path="/Scripting",
                    interface="org.kde.kwin.Scripting",
                    member="loadScript",
                    signature="ss",
                    body=[self.args.kwin_script, SCRIPT_NAME],
                )
            )
            script_id = reply.body[0]
            if script_id < 0:
                raise RuntimeError("KWin rejected xremap mode controller script")
            self.kwin_script_id = script_id
            await self._call(
                Message(
                    destination=KWIN_SERVICE,
                    path=f"/Scripting/Script{script_id}",
                    interface="org.kde.kwin.Script",
                    member="run",
                )
            )
            logging.info("KWin TigerVNC detector loaded")

    async def unload_kwin_script(self):
        async with self.kwin_lock:
            await self._unload_kwin_script()

    async def _unload_kwin_script(self):
        if not await self.dbus.call_name_has_owner(KWIN_SERVICE):
            self.kwin_script_id = None
            return
        try:
            await self._call(
                Message(
                    destination=KWIN_SERVICE,
                    path="/Scripting",
                    interface="org.kde.kwin.Scripting",
                    member="unloadScript",
                    signature="s",
                    body=[SCRIPT_NAME],
                )
            )
        except RuntimeError:
            pass
        self.kwin_script_id = None

    async def _call(self, message):
        reply = await self.bus.call(message)
        if reply.message_type == MessageType.ERROR:
            detail = reply.body[0] if reply.body else reply.error_name
            raise RuntimeError(detail)
        return reply

    def _name_owner_changed(self, name, old_owner, new_owner):
        if name == KWIN_SERVICE:
            if old_owner and not new_owner:
                self.kwin_script_id = None
                asyncio.create_task(self.set_vnc(False))
            elif new_owner:
                asyncio.create_task(self.install_kwin_script())


def synergy_running():
    uid = os.getuid()
    try:
        processes = os.scandir("/proc")
    except OSError:
        return False

    with processes:
        for entry in processes:
            if not entry.name.isdigit():
                continue
            try:
                if entry.stat(follow_symlinks=False).st_uid != uid:
                    continue
                comm = Path(entry.path, "comm").read_text().strip()
                if comm == "synergy-core":
                    return True
                arguments = Path(entry.path, "cmdline").read_bytes().split(b"\0")
                if any(Path(os.fsdecode(arg)).name == "synergy-core" for arg in arguments if arg):
                    return True
            except OSError:
                continue
    return False


def xremap_captures_device(device_name):
    device_paths = set()
    for event in Path("/sys/class/input").glob("event*"):
        try:
            if Path(event, "device/name").read_text().strip() == device_name:
                device_paths.add(f"/dev/input/{event.name}")
        except OSError:
            continue
    if not device_paths:
        return False

    uid = os.getuid()
    try:
        processes = os.scandir("/proc")
    except OSError:
        return False

    with processes:
        for entry in processes:
            if not entry.name.isdigit():
                continue
            try:
                if entry.stat(follow_symlinks=False).st_uid != uid:
                    continue
                if Path(entry.path, "comm").read_text().strip() != "xremap":
                    continue
                for descriptor in Path(entry.path, "fd").iterdir():
                    try:
                        if os.readlink(descriptor) in device_paths:
                            return True
                    except OSError:
                        continue
            except OSError:
                continue
    return False


def process_log_chunk(buffer, chunk, state):
    buffer += chunk
    lines = buffer.split(b"\n")
    for line in lines[:-1]:
        state.process(line.decode(errors="replace"))
    return lines[-1]


async def watch_synergy_log(controller):
    path = Path(controller.args.synergy_log)

    while True:
        state = SynergyState(controller.args.local_screen)
        buffer = b""
        try:
            log = path.open("rb")
        except FileNotFoundError:
            await controller.set_synergy_remote(False)
            await asyncio.sleep(0.5)
            continue

        with log:
            opened = os.fstat(log.fileno())
            while chunk := log.read(65536):
                buffer = process_log_chunk(buffer, chunk, state)
            await controller.set_synergy_remote(state.remote)

            while True:
                chunk = log.read(65536)
                if chunk:
                    previous = state.remote
                    buffer = process_log_chunk(buffer, chunk, state)
                    if state.remote != previous:
                        await controller.set_synergy_remote(state.remote)
                    continue

                try:
                    current = path.stat()
                except FileNotFoundError:
                    await controller.set_synergy_remote(False)
                    break

                if current.st_ino != opened.st_ino or current.st_dev != opened.st_dev:
                    await controller.set_synergy_remote(False)
                    break
                if current.st_size < log.tell():
                    await controller.set_synergy_remote(False)
                    break

                await asyncio.sleep(0.05)


async def watch_synergy_process(controller):
    while True:
        await controller.set_synergy_alive(synergy_running())
        await asyncio.sleep(0.5)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Drive xremap modes from Synergy and TigerVNC"
    )
    parser.add_argument("--synergy-log", required=True)
    parser.add_argument("--local-screen", required=True)
    parser.add_argument("--ydotool", required=True)
    parser.add_argument("--kwin-script", required=True)
    parser.add_argument("--state-file", required=True)
    parser.add_argument("--mac-keycode", type=int, default=194)
    parser.add_argument("--local-keycode", type=int, default=192)
    return parser.parse_args()


async def run():
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    controller = ModeController(args)
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    await controller.attach_bus(bus)
    bus.export(OBJECT_PATH, ModeControllerInterface(controller))
    await bus.request_name(SERVICE_NAME)

    controller.write_state()
    await controller.install_kwin_script()

    tasks = [
        asyncio.create_task(controller.reconcile_forever()),
        asyncio.create_task(watch_synergy_log(controller)),
        asyncio.create_task(watch_synergy_process(controller)),
    ]
    controller.request_reconcile(force=True)
    stopped = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stopped.set)

    await stopped.wait()
    for task in tasks:
        task.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)
    await controller.unload_kwin_script()
    bus.disconnect()


if __name__ == "__main__":
    asyncio.run(run())
