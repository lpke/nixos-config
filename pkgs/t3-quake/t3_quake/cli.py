"""t3-quake command; normal T3 launch remains independent of all helper failures."""
import argparse
import os
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

from PyQt6.QtCore import QCoreApplication
from PyQt6.QtDBus import QDBus, QDBusConnection, QDBusMessage

from .daemon import SERVICE
from .session import running_mode


def call(service, path, interface, method, *arguments):
    message = QDBusMessage.createMethodCall(service, path, interface, method)
    message.setArguments(list(arguments))
    reply = QDBusConnection.sessionBus().call(message, QDBus.CallMode.Block, 2000)
    if reply.type() == QDBusMessage.MessageType.ErrorMessage:
        raise RuntimeError(reply.errorMessage())
    return reply.arguments()


def notify(reason):
    message = reason + '\nT3 can still open normally. Run t3-quake restart to retry.'
    print('T3 quake: ' + message, file=sys.stderr)
    subprocess.run(['notify-send', '--app-name=T3 Quake', '--icon=dialog-warning',
                    '--urgency=normal', '--expire-time=10000', '--hint=boolean:suppress-sound:true',
                    'T3 Quake unavailable', message], timeout=3, check=False)


def launcher():
    return shutil.which('t3code') or str(Path.home() / '.local/bin/t3code')


def launch_quake():
    return subprocess.Popen(['systemd-run', '--user', '--collect', '--quiet',
                             '--unit=t3-quake-app', '--property=Type=exec',
                             launcher(), '--t3-quake'], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def main():
    parser = argparse.ArgumentParser(description='Borrow T3 as a drop-down window; press again to return it.')
    parser.add_argument('command', nargs='?', default='toggle',
                        choices=['launch', 'toggle', 'restore', 'status', 'restart'])
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    app = QCoreApplication(sys.argv)
    launch = None
    try:
        mode = running_mode()
    except (OSError, RuntimeError) as error:
        notify(str(error))
        raise SystemExit(1)
    if args.command == 'launch':
        os.execv(launcher(), [launcher(), '--t3-quake', *args.arguments])
    if args.arguments:
        parser.error('extra arguments are supported only by launch')
    if mode == 'normal' and args.command in ('toggle', 'restart'):
        subprocess.run(['notify-send', '--app-name=T3 Quake', '--icon=dialog-warning',
                        '--hint=boolean:suppress-sound:true', 'Cannot open T3 Quake',
                        'Close T3 Code first, then open T3 Quake.'], check=False)
        raise SystemExit(1)
    try:
        registered = QDBusConnection.sessionBus().interface().isServiceRegistered(SERVICE).value()
        if not registered and args.command in ('status', 'restore'):
            print(json.dumps({'running': False, 'mode': 'normal'}))
            return
        if args.command == 'restart':
            call('org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting', 'unloadScript', 't3-quake')
            call('org.kde.KWin', '/Effects', 'org.kde.kwin.Effects', 'unloadEffect', 't3-quake-slide')
            if not call('org.kde.KWin', '/Effects', 'org.kde.kwin.Effects', 'loadEffect', 't3-quake-slide')[0]:
                raise RuntimeError('The drop-down animation could not be loaded.')
            subprocess.run(['systemctl', '--user', 'restart' if mode == 'quake' else 'stop',
                            't3-quake.service'], check=True, timeout=8)
            # KWin's shared QML engine caches the stable Home Manager symlink URL.
            # A canonical package URL loads the current version without a logout.
            script = Path(__file__).resolve().parents[3] / 'share/kwin/scripts/t3-quake/contents/ui/main.qml'
            call('org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting', 'loadDeclarativeScript',
                 str(script), 't3-quake')
            call('org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting', 'start')
            print('T3 quake restarted.')
            return
        if args.command == 'toggle':
            if mode is None:
                launch = launch_quake()
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                registered = QDBusConnection.sessionBus().interface().isServiceRegistered(SERVICE).value()
                if registered:
                    state = json.loads(call(SERVICE, '/T3Quake', SERVICE, 'Command', 'status')[0])
                    if state.get('connected'):
                        break
                if launch is not None and launch.poll() not in (None, 0):
                    raise RuntimeError('T3 could not be started.')
                time.sleep(.1)
            else:
                raise RuntimeError('The T3 window controller did not become ready.')
        result = call(SERVICE, '/T3Quake', SERVICE, 'Command', args.command)
        if args.command == 'status':
            print(result[0])
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        try:
            notify(str(error))
        except (OSError, subprocess.SubprocessError):
            pass
        raise SystemExit(1)


if __name__ == '__main__':
    main()
