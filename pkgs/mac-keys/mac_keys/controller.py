import asyncio
import logging
import json
import os
from pathlib import Path
import signal
import time

from . import modes, synergy
from .observer import Observer
from .runtime import configuration, directory, notify_service, read_json, write_json


class AttemptState:
    """Keep a failed or stopped attempt from restarting with the controller."""

    def __init__(self, path, session):
        self.path = path
        self.value = read_json(path)
        if self.value.get("session") != session or not {"attempted", "paused"} <= self.value.keys():
            self.value = {"session": session, "attempted": False, "paused": False}
        self.save()

    def save(self):
        write_json(self.path, self.value)

    def claim(self, manual=False):
        if not manual and (self.value["attempted"] or self.value["paused"]):
            return False
        self.value.update(attempted=True, paused=False)
        self.save()
        return True

    def pause(self):
        self.value.update(paused=True)
        self.save()


class Controller:
    def __init__(self, config, snapshot):
        self.config = config
        self.attempt = AttemptState(directory() / "attempt.json", snapshot["session"])
        self.remote = False
        self.application = None
        self.status = "Detection stopped" if self.attempt.value["paused"] else "Waiting for Mac SSH"
        self.error = None
        self.mode_error = None
        self.screen_error = None
        self.applied_mode = None
        self.observer_task = None
        self.changed = asyncio.Event()
        self.stopped = asyncio.Event()
        self.group = None

    @property
    def desired_mode(self):
        return modes.selected_mode(self.remote, self.application, self.config["terminal_applications"])

    def state(self):
        return {"status": self.status, "screen": "Mac" if self.remote else "PC",
                "application": self.application, "desired_mode": self.desired_mode,
                "applied_mode": self.applied_mode, "updated": time.time(),
                "error": self.mode_error or self.screen_error or self.error}

    def publish(self):
        write_json(directory() / "state.json", self.state())

    def update(self, status, application, error):
        if (status, application, error) != (self.status, self.application, self.error):
            logging.info("%s; app=%s; %s", status, application or "unknown", error or "")
        self.status, self.application, self.error = status, application, error
        self.changed.set()
        self.publish()

    def connect(self, manual=False):
        if self.observer_task and not self.observer_task.done():
            return "Detection is already running"
        if not self.attempt.claim(manual):
            return "Run mac-keys retry to connect"
        self.observer_task = self.group.create_task(Observer(self.config, self.update).run())
        return "Connecting to Mac"

    async def stop_detection(self):
        self.attempt.pause()
        if self.observer_task:
            self.observer_task.cancel()
            await asyncio.gather(self.observer_task, return_exceptions=True)
        self.update("Detection stopped", None, None)

    async def handle_command(self, reader, writer):
        try:
            command = (await asyncio.wait_for(reader.readline(), 2)).decode().strip()
            if command == "status":
                response = self.state()
            elif command in {"start", "retry"}:
                response = {"message": self.connect(manual=True)}
            elif command == "stop":
                await self.stop_detection()
                response = {"message": "Detection stopped; SSH remains cached"}
            elif command == "reapply":
                self.applied_mode = None
                self.changed.set()
                response = {"message": "Reapplying mappings"}
            else:
                response = {"error": "Unknown command"}
            writer.write((json.dumps(response) + "\n").encode())
            await writer.drain()
        except (OSError, asyncio.TimeoutError):
            logging.warning("Control request disconnected")
        finally:
            writer.close()
            await writer.wait_closed()

    async def reconcile(self):
        while True:
            await self.changed.wait()
            self.changed.clear()
            while self.applied_mode != self.desired_mode:
                mode = self.desired_mode
                try:
                    await modes.apply(mode)
                    self.applied_mode = mode
                    self.mode_error = None
                except (OSError, asyncio.TimeoutError) as error:
                    message = str(error) or "Mode switch timed out"
                    if message != self.mode_error:
                        logging.warning("%s", message)
                    self.mode_error = message
                    await asyncio.sleep(0.5)
                self.publish()

    async def watch_screen(self):
        path = Path(self.config["synergy_log"])
        while True:
            state = synergy.ScreenState(self.config["local_screen"])
            try:
                with path.open("rb") as log:
                    opened = os.fstat(log.fileno())
                    while True:
                        chunk = log.read(65536)
                        if chunk:
                            state.feed(chunk)
                            continue
                        if self.remote != state.remote:
                            self.remote = state.remote
                            self.changed.set()
                            self.publish()
                        self.screen_error = None
                        await asyncio.sleep(0.05)
                        current = path.stat()
                        if (current.st_ino, current.st_dev) != (opened.st_ino, opened.st_dev) or current.st_size < log.tell():
                            break
            except OSError as error:
                self.screen_error = f"Cannot read Synergy screen state: {error}"
            self.remote = False
            self.changed.set()
            self.publish()
            await asyncio.sleep(0.5)

    async def watch_process(self):
        while True:
            if not synergy.processes()["running"]:
                self.stopped.set()
                return
            self.publish()
            notify_service("WATCHDOG=1")
            await asyncio.sleep(0.5)

    async def run(self):
        socket_path = directory() / "control.sock"
        socket_path.unlink(missing_ok=True)
        server = await asyncio.start_unix_server(self.handle_command, path=socket_path)
        notify_service("READY=1")
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, self.stopped.set)
        try:
            async with server, asyncio.TaskGroup() as group:
                self.group = group
                tasks = [group.create_task(self.reconcile()), group.create_task(self.watch_screen()),
                         group.create_task(self.watch_process())]
                self.connect()
                self.changed.set()
                await self.stopped.wait()
                for task in tasks:
                    task.cancel()
                if self.observer_task:
                    self.observer_task.cancel()
        finally:
            socket_path.unlink(missing_ok=True)
            self.remote = False
            self.update("Synergy stopped", None, None)


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    snapshot = synergy.processes()
    if snapshot["running"]:
        asyncio.run(Controller(configuration(), snapshot).run())


if __name__ == "__main__":
    main()
