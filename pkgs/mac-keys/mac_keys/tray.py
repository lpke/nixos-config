"""Watch Synergy's lifecycle and show controller health independently of it."""

import signal
import sys
import time
from pathlib import Path

from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtGui import QAction, QIcon
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from . import synergy
from .runtime import CONTROLLER_UNIT, describe, directory, read_json


class Tray:
    def __init__(self, app):
        self.app = app
        self.previous = None
        self.commands = set()
        self.lifecycle_error = None
        self.tray = QSystemTrayIcon(app)
        self.menu = QMenu()
        self.summary = self.menu.addAction("Starting")
        self.summary.setEnabled(False)
        self.detail = self.menu.addAction("Mappings: pending")
        self.detail.setEnabled(False)
        self.menu.addSeparator()
        for label, command in (("Start detection", "start"), ("Retry SSH", "retry"),
                               ("Stop detection", "stop")):
            action = QAction(label, self.menu)
            action.triggered.connect(lambda checked=False, command=command: self.command("mac-keys", [command]))
            self.menu.addAction(action)
        self.menu.addSeparator()
        self.menu.addAction("Show logs", lambda: self.command("konsole", ["--hold", "-e", "mac-keys", "logs"]))
        self.menu.addAction("SSH recovery commands", lambda: self.command("konsole", ["--hold", "-e", "mac-keys", "--help"]))
        self.tray.setContextMenu(self.menu)
        assets = Path(__file__).parent.parent / "icons"
        self.icons = {name: QIcon(str(assets / f"{name}.svg")) for name in ("connected", "error")}
        self.tray.setIcon(self.icons["error"])
        self.timer = QTimer(app)
        self.timer.timeout.connect(self.tick)
        self.timer.start(500)
        app.aboutToQuit.connect(self.stop_controller)
        self.tick()

    def command(self, program, arguments, lifecycle=False):
        process = QProcess(self.app)
        self.commands.add(process)

        def finished(code, status):
            if code:
                error = bytes(process.readAllStandardError()).decode(errors="replace").strip()
                error = error or "Command failed; run mac-keys logs"
                if lifecycle:
                    self.lifecycle_error = error
                else:
                    self.tray.showMessage("Mac keys", error, QSystemTrayIcon.MessageIcon.Warning)
            elif lifecycle:
                self.lifecycle_error = None
            self.commands.discard(process)
            process.deleteLater()

        process.finished.connect(finished)
        process.errorOccurred.connect(lambda error: setattr(self, "lifecycle_error", process.errorString()))
        process.start(program, arguments)

    def stop_controller(self):
        QProcess.startDetached("systemctl", ["--user", "--no-block", "stop", CONTROLLER_UNIT])

    def tick(self):
        snapshot = synergy.processes()
        identity = (snapshot["running"], snapshot["session"], snapshot["cores"])
        if identity != self.previous:
            # A core restart changes the service lifetime, but not the saved SSH attempt
            # for its parent Synergy session.
            action = ("start" if self.previous is None else "restart") if snapshot["running"] else "stop"
            self.command("systemctl", ["--user", action, CONTROLLER_UNIT], lifecycle=True)
            self.previous = identity
        self.tray.setVisible(snapshot["running"])
        if not snapshot["running"]:
            return
        state = read_json(directory() / "state.json")
        if time.time() - state.get("updated", 0) > 4:
            state = {"status": "Controller unavailable", "error": "Run mac-keys start or check mac-keys logs"}
        if self.lifecycle_error:
            state = {**state, "error": self.lifecycle_error}
        healthy = state.get("status") == "Connected" and not state.get("error")
        self.tray.setIcon(self.icons["connected" if healthy else "error"])
        self.tray.setToolTip("Mac keys\n" + describe(state))
        self.summary.setText(state.get("status", "Controller unavailable"))
        self.detail.setText(f"{state.get('application') or 'App unknown'} · {state.get('applied_mode') or 'Mappings pending'}")


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("mac-keys")
    app.setApplicationDisplayName("Synergy Mac keys")
    app.setQuitOnLastWindowClosed(False)
    tray = Tray(app)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *args: app.quit())
    app.exec()
    del tray


if __name__ == "__main__":
    main()
