"""t3-quake command; normal T3 launch remains independent of all helper failures."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

from PyQt6.QtCore import QCoreApplication
from PyQt6.QtDBus import QDBusConnection, QDBusInterface, QDBusMessage

from .daemon import SERVICE


def call(service, path, interface, method, *arguments):
    remote = QDBusInterface(service, path, interface, QDBusConnection.sessionBus())
    remote.setTimeout(2000)
    reply = remote.call(method, *arguments)
    if reply.type() == QDBusMessage.MessageType.ErrorMessage:
        raise RuntimeError(reply.errorMessage())
    return reply.arguments()


def notify(reason):
    message = reason + '\nT3 can still open normally. Run t3-quake restart to retry.'
    print('T3 quake: ' + message, file=sys.stderr)
    subprocess.run(['notify-send', '--app-name=T3 quake', '--icon=dialog-warning',
                    '--urgency=critical', '--hint=boolean:suppress-sound:true',
                    'T3 quake unavailable', message], timeout=3, check=False)


def launch_normal():
    launcher = shutil.which('t3code') or str(Path.home() / '.local/bin/t3code')
    return subprocess.Popen([launcher], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def main():
    parser = argparse.ArgumentParser(description='Borrow T3 as a drop-down window; press again to return it.')
    parser.add_argument('command', nargs='?', default='toggle',
                        choices=['toggle', 'restore', 'status', 'restart'])
    args = parser.parse_args()
    app = QCoreApplication(sys.argv)
    launch = None
    try:
        registered = QDBusConnection.sessionBus().interface().isServiceRegistered(SERVICE).value()
        if not registered and args.command in ('status', 'restore'):
            print(json.dumps({'running': False, 'mode': 'normal'}))
            return
        if args.command == 'restart':
            call('org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting', 'unloadScript', 't3-quake')
            subprocess.run(['systemctl', '--user', 'restart', 't3-quake.service'], check=True, timeout=5)
            call('org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting', 'start')
            print('T3 quake restarted.')
            return
        if args.command == 'toggle':
            # If T3 is closed, start its ordinary launcher and let its window
            # activate the compositor controller. Never attach to its backend.
            state = json.loads(call(SERVICE, '/T3Quake', SERVICE, 'Command', 'status')[0])
            if not state.get('connected'):
                launch = launch_normal()
        result = call(SERVICE, '/T3Quake', SERVICE, 'Command', args.command)
        if launch is not None:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                state = json.loads(call(SERVICE, '/T3Quake', SERVICE, 'Command', 'status')[0])
                if state.get('connected'):
                    break
                if launch.poll() not in (None, 0):
                    raise RuntimeError('T3 could not be started.')
                time.sleep(.1)
            else:
                raise RuntimeError('The T3 window controller did not become ready.')
        if args.command == 'status':
            print(result[0])
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        if args.command == 'toggle' and launch is None:
            try:
                launch_normal()
            except OSError:
                pass
        try:
            notify(str(error))
        except (OSError, subprocess.SubprocessError):
            pass
        raise SystemExit(1)


if __name__ == '__main__':
    main()
