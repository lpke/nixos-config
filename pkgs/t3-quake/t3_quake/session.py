"""Read the launcher's mode lease without starting any desktop service."""
import fcntl
import json
import os
from pathlib import Path


def running_mode():
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    with (runtime / 't3code-launch.lock').open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return None
        except BlockingIOError:
            try:
                return json.loads((runtime / 't3code-launch.json').read_text())['mode']
            except (OSError, ValueError, KeyError):
                raise RuntimeError('T3 is starting. Please wait and try again.')
