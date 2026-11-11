"""Execute the production error command on the private bus; no real user manager."""
import os
from pathlib import Path
import signal
import subprocess
import sys
from PyQt6.QtCore import QCoreApplication, QObject, pyqtClassInfo, pyqtSlot
from PyQt6.QtDBus import QDBusConnection, QDBusObjectPath

if os.environ.get('DBUS_SESSION_BUS_ADDRESS') != 'unix:path=/lab/runtime/bus':
    raise SystemExit('Private test bus required')


@pyqtClassInfo('D-Bus Interface', 'org.freedesktop.systemd1.Manager')
class Manager(QObject):
    @pyqtSlot(str, str, result=QDBusObjectPath)
    def StopUnit(self, name, mode):
        if name != 't3-quake.service' or mode != 'replace':
            raise ValueError('Unexpected unit request')
        pid = int(Path('/lab/controller.pid').read_text())
        try:
            command = Path(f'/proc/{pid}/cmdline').read_bytes()
            if not command:  # Already-exited child awaiting its parent's wait().
                return QDBusObjectPath('/org/freedesktop/systemd1/job/2')
            if b't3_quake.daemon' not in command:
                raise ValueError('Refusing to stop a process other than the private helper')
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, FileNotFoundError):
            pass
        return QDBusObjectPath('/org/freedesktop/systemd1/job/2')

    @pyqtSlot(str, str, result=QDBusObjectPath)
    def StartUnit(self, name, mode):
        if name != 't3-quake-error.service' or mode != 'replace':
            raise ValueError('Unexpected unit request')
        subprocess.Popen(['sh', '/src/pkgs/t3-quake/error.sh'])
        return QDBusObjectPath('/org/freedesktop/systemd1/job/1')


app = QCoreApplication(sys.argv)
bus = QDBusConnection.sessionBus()
manager = Manager()
assert bus.registerService('org.freedesktop.systemd1')
assert bus.registerObject('/org/freedesktop/systemd1', manager, QDBusConnection.RegisterOption.ExportAllSlots)
app.exec()
