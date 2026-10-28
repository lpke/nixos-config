import asyncio
import logging
import json
import os
from pathlib import Path
import signal
import time

from . import modes, synergy
from .runtime import configuration, directory, notify_service, write_json


class Controller:
    def __init__(self, config):
        self.config = config
        self.remote = False
        self.status = "Mac-local app shortcuts"
        self.mode_error = None
        self.screen_error = None
        self.applied_mode = None
        self.changed = asyncio.Event()
        self.stopped = asyncio.Event()

    @property
    def desired_mode(self):
        return "mac" if self.remote else "local"

    def state(self):
        return {"status": self.status, "screen": "Mac" if self.remote else "PC",
                "desired_mode": self.desired_mode,
                "applied_mode": self.applied_mode, "updated": time.time(),
                "error": self.mode_error or self.screen_error}

    def publish(self):
        write_json(directory() / "state.json", self.state())

    async def handle_command(self, reader, writer):
        try:
            command = (await asyncio.wait_for(reader.readline(), 2)).decode().strip()
            if command == "status":
                response = self.state()
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
        state = synergy.ScreenState(self.config["local_screen"])
        while True:
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
                            state.buffer = b""
                            break
                continue
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
                tasks = [group.create_task(self.reconcile()), group.create_task(self.watch_screen()),
                         group.create_task(self.watch_process())]
                self.changed.set()
                await self.stopped.wait()
                for task in tasks:
                    task.cancel()
        finally:
            socket_path.unlink(missing_ok=True)
            self.remote = False
            self.status = "Synergy stopped"
            self.publish()


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    snapshot = synergy.processes()
    if snapshot["running"]:
        asyncio.run(Controller(configuration()).run())


if __name__ == "__main__":
    main()
