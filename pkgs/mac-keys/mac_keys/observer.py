"""One explicit SSH attempt; a separate user unit owns the cached connection."""

import asyncio
from pathlib import Path

from .runtime import SSH_UNIT


async def run_command(*command):
    process = await asyncio.create_subprocess_exec(
        *command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
    )
    try:
        output, error = await asyncio.wait_for(process.communicate(), 10)
        return process.returncode, output, error
    finally:
        if process.returncode is None:
            process.kill()
            await process.wait()


class Observer:
    def __init__(self, config, update):
        self.config = config
        self.update = update

    def ssh(self):
        return ["ssh", "-T", "-S", self.config["ssh_socket"],
                "-o", "BatchMode=yes", "-o", "ControlMaster=no",
                # If the cached master disappears, do not silently open another connection.
                "-o", "ProxyCommand=false"]

    async def connect(self):
        code, _, _ = await run_command(*self.ssh(), "-O", "check", self.config["host"])
        if code == 0:
            return
        code, _, error = await run_command("systemctl", "--user", "start", SSH_UNIT)
        if code:
            raise OSError(error.decode(errors="replace").strip())
        # These checks inspect a local socket; only the SSH unit makes a connection attempt.
        for _ in range(30):
            code, _, _ = await run_command(*self.ssh(), "-O", "check", self.config["host"])
            if code == 0:
                return
            active, _, _ = await run_command("systemctl", "--user", "is-active", "--quiet", SSH_UNIT)
            if active:
                break
            await asyncio.sleep(0.2)
        raise OSError("SSH connection failed. See mac-keys --help for Mac recovery commands.")

    async def run(self):
        process = None
        self.update("Connecting to Mac", None, None)
        try:
            await self.connect()
            process = await asyncio.create_subprocess_exec(
                *self.ssh(), self.config["host"], "/usr/bin/osascript -l JavaScript -",
                stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            process.stdin.write(Path(self.config["observer_script"]).read_bytes())
            await process.stdin.drain()
            process.stdin.close()
            while True:
                line = await asyncio.wait_for(process.stdout.readline(), 8)
                if not line:
                    error = (await process.stderr.read(4096)).decode(errors="replace").strip()
                    raise OSError(error or "Mac app observer disconnected")
                application = line.decode(errors="replace").strip() or None
                self.update("Connected", application, None if application else "Mac app is unknown")
        except (OSError, asyncio.TimeoutError) as error:
            self.update("Waiting for Mac SSH", None, str(error) or "No app report for eight seconds")
        finally:
            if process is not None and process.returncode is None:
                process.terminate()
                try:
                    await asyncio.wait_for(process.wait(), 2)
                except asyncio.TimeoutError:
                    process.kill()
                    await process.wait()
