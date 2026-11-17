"""Systemd owns the tray lifetime; its stop hook always retires the tiler."""

import os
from pathlib import Path
import subprocess


TRAY_UNIT = 'krohnkite-tray.service'


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=40)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f'{args[0]} exited with status {result.returncode}')
    return result.stdout.strip()


def tray_state():
    return command('systemctl', '--user', 'show', TRAY_UNIT, '--property=ActiveState', '--value')


def launch():
    command('systemctl', '--user', 'start', TRAY_UNIT)


def quit_app():
    # A menu command belongs to the tray's cgroup. Return before systemd stops it.
    command('systemctl', '--user', '--no-block', 'stop', TRAY_UNIT)


def enable(enabled):
    command('kwriteconfig6', '--file', 'kwinrc', '--group', 'Plugins',
            '--key', 'krohnkiteEnabled', '--type', 'bool', str(enabled).lower())


def open_help():
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'krohnkite'
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = cache / 'help.md'
    path.write_text(Path(__file__).with_name('help.md').read_text())
    os.execvp('alacritty', ['alacritty', '-e', 'nvim', '--', str(path)])
