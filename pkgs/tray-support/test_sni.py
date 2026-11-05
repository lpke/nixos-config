"""Exercise KDE's real SNI export on an isolated bus at fractional and mixed DPI."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parents[2]


def bus(*args):
    return json.loads(subprocess.check_output(["busctl", "--user", "--json=short", "--", *args],
                                             text=True, stderr=subprocess.DEVNULL))["data"]


def fixture():
    from PyQt6.QtCore import QCoreApplication, QObject, QTimer, pyqtClassInfo, pyqtProperty, pyqtSlot
    from PyQt6.QtDBus import QDBusConnection
    from PyQt6.QtWidgets import QApplication
    QCoreApplication.addLibraryPath("/run/current-system/sw/lib/qt-6/plugins")
    app = QApplication([])
    app.setApplicationDisplayName("Isolated SVG test")
    app.setQuitOnLastWindowClosed(False)
    @pyqtClassInfo("D-Bus Interface", "org.kde.StatusNotifierWatcher")
    class Watcher(QObject):
        @pyqtSlot(str)
        def RegisterStatusNotifierItem(self, service):
            pass

        @pyqtProperty(bool)
        def IsStatusNotifierHostRegistered(self):
            return True

        @pyqtProperty(int)
        def ProtocolVersion(self):
            return 0

    watcher = Watcher()
    connection = QDBusConnection.sessionBus()
    assert connection.registerService("org.kde.StatusNotifierWatcher")
    assert connection.registerObject("/StatusNotifierWatcher", watcher,
                                     QDBusConnection.RegisterOption.ExportAllSlots
                                     | QDBusConnection.RegisterOption.ExportAllProperties)
    from unittest.mock import patch
    from t3_tray.tray import Tray
    with patch.object(Tray, "tick"):
        tray = Tray(app)
    tray.timer.stop()
    QTimer.singleShot(10000, app.quit)
    app.exec()


def check():
    for scale in ("1.25", "2"):
        environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QPA_PLATFORMTHEME": "kde",
                       "QT_SCALE_FACTOR": scale, "XDG_CURRENT_DESKTOP": "KDE"}
        process = subprocess.Popen([sys.executable, "-B", __file__, "fixture"], env=environment,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                names = bus("call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                            "org.freedesktop.DBus", "ListNames")[0]
                name = None
                for candidate in names:
                    if not candidate.startswith(":"):
                        continue
                    try:
                        icon_name = bus("get-property", candidate, "/StatusNotifierItem",
                                        "org.kde.StatusNotifierItem", "IconName")
                    except subprocess.SubprocessError:
                        continue
                    name = candidate
                    break
                if name:
                    break
                if process.poll() is not None:
                    raise AssertionError(process.stderr.read())
                time.sleep(.05)
            else:
                raise AssertionError("KDE did not export its SNI service: " + repr(names))
            icon_name = bus("get-property", name, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "IconName")
            path = Path(icon_name)
            assert path.is_absolute() and path.suffix == ".svg" and path.is_file(), icon_name
            assert 'viewBox="0 0 32 32"' in path.read_text()
            menu = bus("get-property", name, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "Menu")
            layout = bus("call", name, menu, "com.canonical.dbusmenu", "GetLayout", "iias", "0", "-1", "0")
            def labels(node):
                _, properties, children = node
                if "label" in properties:
                    yield properties["label"]["data"]
                for child in children:
                    yield from labels(child["data"])
            exported = list(labels(layout[1]))
            from t3_tray.tray import MENU_RIGHT_GUTTER, TRANSPORTS
            for title, _ in TRANSPORTS.values():
                assert title + MENU_RIGHT_GUTTER in exported, exported
            print(f"scale={scale}: SNI exports original SVG and full submenu labels with right gutter")
        finally:
            process.terminate()
            process.communicate(timeout=5)


if __name__ == "__main__":
    if sys.argv[-1] == "fixture":
        fixture()
    elif sys.argv[-1] == "check":
        check()
    else:
        with tempfile.TemporaryDirectory(prefix="tray-sni-tests-") as temporary:
            config = Path(temporary) / "session.conf"
            config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>'
                              '<policy context="default"><allow send_destination="*"/>'
                              '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
            environment = {**os.environ, "XDG_CACHE_HOME": temporary,
                           "PYTHONPATH": os.pathsep.join(str(ROOT / "pkgs" / name)
                                                         for name in ("tray-support", "t3-tray"))}
            result = subprocess.run(["dbus-run-session", "--config-file=" + str(config), "--",
                                     sys.executable, "-B", __file__, "check"], env=environment)
            sys.exit(result.returncode)
