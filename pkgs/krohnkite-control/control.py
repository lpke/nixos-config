"""Refresh Krohnkite settings, or explicitly replace its script bundle."""

import argparse
import fcntl
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time

from PyQt6.QtCore import QCoreApplication, QObject, QTimer, pyqtClassInfo, pyqtSlot
from PyQt6.QtDBus import QDBusConnection, QDBusMessage


SERVICE = 'io.github.lpke.KrohnkiteReload'
INTERFACE = 'org.kde.kwin.Scripting'
PLUGIN = 'krohnkite'


class StopRefused(RuntimeError):
    pass


def call(bus, service, path, interface, method, *args):
    message = QDBusMessage.createMethodCall(service, path, interface, method)
    message.setArguments(list(args))
    reply = bus.call(message, timeout=5000)
    if reply.type() == QDBusMessage.MessageType.ErrorMessage:
        raise RuntimeError(reply.errorMessage())
    return reply.arguments()


def scripting(bus, method, *args):
    return call(bus, 'org.kde.KWin', '/Scripting', INTERFACE, method, *args)


def wait_unloaded(bus):
    deadline = time.monotonic() + 5
    while scripting(bus, 'isScriptLoaded', PLUGIN)[0]:
        if time.monotonic() > deadline:
            raise RuntimeError('Krohnkite did not finish stopping; no replacement was started.')
        time.sleep(.05)


def stage(source, cache):
    for name in ('metadata.json', 'contents/ui/main.qml', 'contents/code/script.js'):
        if not (source / name).is_file():
            raise RuntimeError(f'Incomplete Krohnkite package: {source / name}')
    bundle = Path(tempfile.mkdtemp(prefix='bundle-', dir=cache))
    shutil.copytree(source, bundle, dirs_exist_ok=True)
    # Nix store permissions must not make later cache cleanup fail.
    bundle.chmod(0o700)
    for path in bundle.rglob('*'):
        path.chmod(0o700 if path.is_dir() else 0o600)
    return bundle


def activate(bus, bundle, *, loaded=True):
    if loaded:
        if not scripting(bus, 'unloadScript', PLUGIN)[0]:
            raise StopRefused('KWin refused to stop Krohnkite; no replacement was started.')
        wait_unloaded(bus)
    identity = scripting(bus, 'loadDeclarativeScript', str(bundle / 'contents/ui/main.qml'), PLUGIN)[0]
    if identity < 0:
        raise RuntimeError('KWin refused the replacement Krohnkite bundle.')
    # KWin can reuse a D-Bus object ID after unload. Start via the manager.
    scripting(bus, 'start')


def replace(bus, source, cache):
    # Copy every dependency, not just main.qml: Qt caches imported JS by URL.
    bundle = stage(source, cache)
    try:
        activate(bus, bundle)
    except StopRefused:
        shutil.rmtree(bundle)
        raise
    return bundle


@pyqtClassInfo('D-Bus Interface', SERVICE)
class Completion(QObject):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.result = None

    @pyqtSlot(str)
    def Done(self, result):
        self.result = result
        self.app.exit(0 if result == 'ok' else 1)


def acknowledge(bus, app):
    completion = Completion(app)
    if not bus.registerService(SERVICE):
        raise RuntimeError('Another Krohnkite reload is already running.')
    if not bus.registerObject('/Reload', completion, QDBusConnection.RegisterOption.ExportAllSlots):
        bus.unregisterService(SERVICE)
        raise RuntimeError('Could not register the reload completion handler.')
    timer = QTimer()
    timer.setSingleShot(True)
    timer.timeout.connect(lambda: app.exit(1))

    def request():
        call(bus, 'org.kde.kglobalaccel', '/component/kwin',
             'org.kde.kglobalaccel.Component', 'invokeShortcut', 'KrohnkiteReloadConfig')

    # Queue the request so the event loop can receive KWin's completion reply.
    error = []
    def start():
        try:
            request()
        except RuntimeError as failure:
            error.append(str(failure))
            app.exit(1)
    QTimer.singleShot(0, start)
    timer.start(5000)
    try:
        app.exec()
    finally:
        timer.stop()
        bus.unregisterObject('/Reload')
        bus.unregisterService(SERVICE)
    if error:
        raise RuntimeError(error[0])
    if completion.result is None:
        raise RuntimeError('The running tiler did not acknowledge reload. Run krohnkite restart to load the installed script.')
    if completion.result != 'ok':
        raise RuntimeError(completion.result)


def main():
    parser = argparse.ArgumentParser(prog='krohnkite', description=__doc__)
    parser.add_argument('action', choices=['reload', 'restart'], nargs='?', default='reload',
                        help='reload settings in place; restart replaces code and resets runtime layout choices')
    args = parser.parse_args()
    app = QCoreApplication(sys.argv)
    bus = QDBusConnection.sessionBus()
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'krohnkite-control'
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (cache / 'actions.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not scripting(bus, 'isScriptLoaded', PLUGIN)[0]:
            raise RuntimeError('Krohnkite is disabled; enable it in KWin Scripts first.')
        bundle = None
        previous = cache / 'last-good'
        old_bundle = Path(previous.read_text().strip()) if previous.is_file() else None
        if old_bundle and (old_bundle.parent != cache or not old_bundle.is_dir()):
            old_bundle = None
        try:
            if args.action == 'restart':
                bundle = replace(bus, Path(os.environ['KROHNKITE_PACKAGE']), cache)
            # Reparse kwinrc without restarting the compositor or the tiler.
            call(bus, 'org.kde.KWin', '/KWin', 'org.kde.KWin', 'reconfigure')
            acknowledge(bus, app)
        except StopRefused:
            raise
        except RuntimeError as error:
            if args.action != 'restart' or old_bundle is None:
                raise
            try:
                activate(bus, old_bundle, loaded=scripting(bus, 'isScriptLoaded', PLUGIN)[0])
                acknowledge(bus, app)
            except RuntimeError as recovery:
                raise RuntimeError(f'{error} Recovery also failed: {recovery}') from error
            raise RuntimeError(f'{error} Restored the previous working script bundle.') from error
        if bundle:
            temporary = cache / 'last-good.tmp'
            temporary.write_text(str(bundle))
            temporary.replace(previous)
            for old in cache.glob('bundle-*'):
                if old.is_dir() and old != bundle:
                    shutil.rmtree(old)
        print('Krohnkite settings reloaded.' if bundle is None else 'Krohnkite script restarted.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, OSError) as error:
        print(f'Krohnkite: {error}', file=sys.stderr)
        sys.exit(1)
