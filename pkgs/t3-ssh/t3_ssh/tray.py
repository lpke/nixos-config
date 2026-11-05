"""Small Qt tray, matching the local Synergy tray's process/menu pattern."""

import json
import signal
import sys

from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from .runtime import ASSETS


class Tray:
    def __init__(self, app):
        self.app = app
        self.commands = set()
        self.polling = False
        self.closing = False
        app.aboutToQuit.connect(self.shutdown)
        self.tray = QSystemTrayIcon(app)
        self.icons = {name: QIcon(str(ASSETS / "icons" / f"{name}.svg")) for name in ("connected", "error")}
        self.menu = QMenu()
        self.summary = self.menu.addAction("Connecting")
        self.summary.setEnabled(False)
        self.menu.addSeparator()
        self.start = self.menu.addAction("Start", lambda: self.command(["start"]))
        self.pause = self.menu.addAction("Pause", lambda: self.command(["stop"]))
        self.menu.addSeparator()
        self.menu.addAction("Show logs", lambda: self.command(
            ["--hold", "-e", "t3-ssh", "logs"], program="konsole"))
        self.menu.addAction("Help", lambda: self.command(["help"]))
        self.menu.addSeparator()
        self.menu.addAction("Quit", lambda: self.command(["quit"]))
        self.tray.setContextMenu(self.menu)
        self.tray.setIcon(self.icons["error"])
        self.tray.setToolTip("T3 SSH\nConnecting")
        self.tray.show()
        self.timer = QTimer(app)
        self.timer.timeout.connect(self.tick)
        self.timer.start(2000)
        self.tick()

    def display(self, state):
        self.tray.setIcon(self.icons["connected" if state.get("connected") else "error"])
        status = state.get("status", "Connection error")
        self.summary.setText(status)
        self.tray.setToolTip(f"T3 SSH\n{status}\n{state.get('detail', '')}")
        self.pause.setEnabled(bool(state.get("active")))
        self.start.setEnabled(not state.get("active"))

    def command(self, arguments, program="t3-ssh", polling=False):
        process = QProcess(self.app)
        self.commands.add(process)

        def finished(code, status):
            if polling:
                self.polling = False
                try:
                    self.display(json.loads(bytes(process.readAllStandardOutput())))
                except (ValueError, UnicodeError):
                    self.display({"detail": "Status check failed. Open Help or Show logs."})
            elif code:
                detail = bytes(process.readAllStandardError()).decode(errors="replace").strip()
                self.tray.showMessage("T3 SSH", detail or "Command failed. Open Help or Show logs.",
                                      QSystemTrayIcon.MessageIcon.Warning)
            else:
                self.tick()
            self.commands.discard(process)
            process.deleteLater()

        def failed(error):
            if error != QProcess.ProcessError.FailedToStart:
                return  # Crashes also emit finished; let that handler clean up.
            if polling:
                self.polling = False
            self.display({"detail": process.errorString()})
            self.commands.discard(process)
            process.deleteLater()

        process.finished.connect(finished)
        process.errorOccurred.connect(failed)
        process.start(program, arguments)

    def tick(self):
        if not self.closing and not self.polling:
            self.polling = True
            self.command(["status", "--json"], polling=True)

    def shutdown(self):
        # Disconnect callbacks before Qt destroys QProcess children. A running
        # status check otherwise emits finished while its wrapper is deleted.
        self.closing = True
        self.timer.stop()
        for process in tuple(self.commands):
            process.blockSignals(True)
            if process.state() != QProcess.ProcessState.NotRunning:
                process.kill()
                process.waitForFinished(1000)
        self.commands.clear()
        self.polling = False
        self.tray.hide()


def main():
    app = QApplication(sys.argv)
    # Qt exports the display name as its StatusNotifierItem id in Plasma.
    app.setApplicationName("t3-ssh")
    app.setApplicationDisplayName("T3 SSH")
    app.setQuitOnLastWindowClosed(False)
    tray = Tray(app)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *args: app.quit())
    app.exec()
    del tray


if __name__ == "__main__":
    main()
