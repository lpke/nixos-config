"""One asynchronous tray with separately controlled T3 transports."""

import json
import signal
import sys

from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from .icons import icons


TRANSPORTS = {"tailscale": ("Tailscale · solid left", "t3-tailscale"),
              "ssh": ("SSH · dotted right", "t3-ssh")}
# Plasma imports the menu over D-Bus, so a widget stylesheet cannot set its
# padding. Nonbreaking spaces reserve a font-scaled gutter before its arrow.
MENU_RIGHT_GUTTER = "\u00a0" * 3


class Tray:
    def __init__(self, app):
        self.app = app
        self.commands = set()
        self.polling = set()
        self.closing = False
        self.states = {key: {"status": "Checking", "connected": False, "active": False}
                       for key in TRANSPORTS}
        self.icons = icons()
        self.icon_state = None
        self.tray = QSystemTrayIcon(app)
        self.menu = QMenu()
        self.actions = {}
        for key, (title, program) in TRANSPORTS.items():
            menu = self.menu.addMenu(title + MENU_RIGHT_GUTTER)
            summary = menu.addAction("Checking")
            summary.setEnabled(False)
            menu.addSeparator()
            start = menu.addAction("Start", lambda checked=False, k=key: self.control(k, "start"))
            pause = menu.addAction("Pause", lambda checked=False, k=key: self.control(k, "stop"))
            menu.addSeparator()
            menu.addAction("Show logs", lambda checked=False, p=program:
                           self.command("konsole", ["--hold", "-e", p, "logs"]))
            menu.addAction("Help", lambda checked=False, p=program: self.command(p, ["help"]))
            self.actions[key] = {"summary": summary, "start": start, "pause": pause, "menu": menu}
        self.menu.addSeparator()
        self.menu.addAction("Quit tray", lambda: app.quit())
        self.tray.setContextMenu(self.menu)
        self.display()
        self.tray.show()
        app.aboutToQuit.connect(self.shutdown)
        self.timer = QTimer(app)
        self.timer.timeout.connect(self.tick)
        self.timer.start(2000)
        self.tick()

    def display(self):
        state = tuple(bool(self.states[key].get("connected")) for key in TRANSPORTS)
        if state != self.icon_state:
            self.tray.setIcon(self.icons[state])
            self.icon_state = state
        lines = ["T3 connections"]
        for key, (title, _) in TRANSPORTS.items():
            status = self.states[key]
            self.actions[key]["summary"].setText(status.get("status", "Connection error"))
            self.actions[key]["pause"].setEnabled(bool(status.get("active")))
            self.actions[key]["start"].setEnabled(not status.get("active"))
            lines.append(f"{title}: {status.get('status', 'Connection error')}")
            if status.get("detail"):
                lines.append(status["detail"])
        self.tray.setToolTip("\n".join(lines))

    def update(self, key, state):
        self.states[key] = state
        self.display()

    def control(self, key, action):
        self.command(TRANSPORTS[key][1], [action])

    def command(self, program, arguments, polling=None):
        process = QProcess(self.app)
        self.commands.add(process)

        def cleanup():
            if polling:
                self.polling.discard(polling)
            self.commands.discard(process)
            process.deleteLater()

        def finished(code, status):
            if polling:
                try:
                    state = json.loads(bytes(process.readAllStandardOutput()))
                    if not isinstance(state, dict):
                        raise ValueError("Expected status object")
                except (ValueError, UnicodeError):
                    state = {"status": "Connection error", "detail": "Status check failed. Open Help or Show logs."}
                self.update(polling, state)
            elif code:
                detail = bytes(process.readAllStandardError()).decode(errors="replace").strip()
                self.tray.showMessage("T3", detail or "Command failed. Open Help or Show logs.",
                                      QSystemTrayIcon.MessageIcon.Warning)
            cleanup()
            if not polling:
                self.tick()

        def failed(error):
            if error != QProcess.ProcessError.FailedToStart:
                return
            if polling:
                self.update(polling, {"status": "Connection error", "detail": process.errorString()})
            else:
                self.tray.showMessage("T3", process.errorString(), QSystemTrayIcon.MessageIcon.Warning)
            cleanup()

        process.finished.connect(finished)
        process.errorOccurred.connect(failed)
        process.start(program, arguments)

    def tick(self):
        if self.closing:
            return
        for key, (_, program) in TRANSPORTS.items():
            if key not in self.polling:
                self.polling.add(key)
                self.command(program, ["status", "--json"], polling=key)

    def shutdown(self):
        self.closing = True
        self.timer.stop()
        for process in tuple(self.commands):
            process.blockSignals(True)
            if process.state() != QProcess.ProcessState.NotRunning:
                process.kill()
                process.waitForFinished(1000)
        self.commands.clear()
        self.polling.clear()
        self.tray.hide()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("t3-tray")
    app.setApplicationDisplayName("T3")
    app.setQuitOnLastWindowClosed(False)
    tray = Tray(app)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *args: app.quit())
    app.exec()
    del tray


if __name__ == "__main__":
    main()
