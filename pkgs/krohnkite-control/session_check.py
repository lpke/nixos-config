"""Opt-in service lifecycle checks; all tiling and Qt UI use a private session."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import uuid


def check(root, cli):
    root, cli = Path(root), Path(cli)
    private_bus = os.environ['DBUS_SESSION_BUS_ADDRESS']
    if str(root / 'runtime') not in private_bus or os.environ.get('XDG_CONFIG_HOME') != str(root / 'config'):
        raise RuntimeError('Lifecycle checks require the isolated KWin bus and configuration.')
    host_env = os.environ | {'DBUS_SESSION_BUS_ADDRESS': os.environ['KROHNKITE_TEST_HOST_BUS'],
                             'XDG_RUNTIME_DIR': os.environ['KROHNKITE_TEST_HOST_RUNTIME']}
    unit = f'krohnkite-check-{uuid.uuid4().hex}.service'

    def manager(*args, check=True):
        result = subprocess.run(args, env=host_env, capture_output=True, text=True, timeout=35)
        if check and result.returncode:
            raise RuntimeError(result.stderr.strip() or f'{args[0]} failed')
        return result

    def control(*args):
        return subprocess.run([str(cli), *args], check=True, capture_output=True, text=True, timeout=15).stdout

    def running():
        return json.loads(control('status', '--json'))['running']

    def wait_stopped():
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            result = manager('systemctl', '--user', 'show', unit, '--property=ActiveState', '--value', check=False)
            if result.stdout.strip() not in ('active', 'activating', 'deactivating') and not running():
                return
            time.sleep(.1)
        raise RuntimeError('Tray shutdown did not stop the private tiler.')

    def launch():
        arguments = ['systemd-run', '--user', '--collect', f'--unit={unit}',
                     '--property=Restart=no', '--property=KillMode=control-group',
                     '--property=Nice=15', '--property=CPUQuota=25%',
                     '--property=TimeoutStartSec=30', '--property=TimeoutStopSec=20',
                     f'--property=ExecStartPost={cli} --backend start',
                     f'--property=ExecStopPost={cli} --backend stop']
        environment = {key: os.environ[key] for key in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME',
                       'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR', 'XDG_STATE_HOME', 'XDG_CONFIG_DIRS')}
        environment.update(DBUS_SESSION_BUS_ADDRESS=private_bus, QT_QPA_PLATFORM='offscreen',
                           WAYLAND_DISPLAY='', DISPLAY='', DBUS_SYSTEM_BUS_ADDRESS=str(root / 'no-system-bus'))
        arguments.extend(f'--setenv={key}={value}' for key, value in environment.items())
        arguments.append(str(cli.with_name('krohnkite-tray')))
        manager(*arguments)
        assert running(), 'Service startup must start tiling.'
        pid = int(manager('systemctl', '--user', 'show', unit, '--property=MainPID', '--value').stdout.strip())
        assert pid > 0
        return pid

    try:
        pid = launch()
        control('--backend', 'stop')
        assert not running()
        os.kill(pid, 0)
        assert manager('systemctl', '--user', 'is-active', unit).stdout.strip() == 'active'
        # Reconfigure must respect Stop, just as it does during a rebuild.
        subprocess.run(['qdbus', 'org.kde.KWin', '/KWin', 'org.kde.KWin.reconfigure'], check=True,
                       capture_output=True, timeout=5)
        time.sleep(.3)
        assert not running()
        control('--backend', 'start')
        assert running()
        assert int(manager('systemctl', '--user', 'show', unit, '--property=MainPID', '--value').stdout) == pid
        print('SERVICE_CHECK PASS Stop keeps the tray alive; Start restores tiling; rebuild reconfigure respects Stop')
        manager('systemctl', '--user', 'kill', '--signal=SIGKILL', '--kill-whom=main', unit)
        wait_stopped()
        print('SERVICE_CHECK PASS SIGKILL still executes tiler cleanup')
        launch()
        manager('systemctl', '--user', 'stop', unit)
        wait_stopped()
        print('SERVICE_CHECK PASS relaunch restores tray/tiler and normal Quit cleans up')
    finally:
        manager('systemctl', '--user', 'stop', unit, check=False)
        manager('systemctl', '--user', 'reset-failed', unit, check=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root')
    parser.add_argument('cli')
    args = parser.parse_args()
    check(args.root, args.cli)
