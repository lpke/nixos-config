"""One tray for Synergy sharing and its independent keyboard controller."""

import signal
import sys
import time

from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon
from tray_icon import primary_click_opens_menu, svg_icon

from . import controls, synergy
from .runtime import CONTROLLER_UNIT, describe, directory, read_json


SYNERGY_COLORS = ("#2cba97", "#2eacc4", "#88d32f", "#3968d3")
WHITE = "#ffffff"
RED = "#da4453"


def icon_svg(sharing, keys):
    pointer = WHITE if keys else RED
    # Match T3's 13px radius and 2.6px stroke on the same 32px canvas.
    arcs = (
        "M19.36 3.44 A13 13 0 0 1 28.56 19.36",
        "M28.56 19.36 A13 13 0 0 1 12.64 28.56",
        "M12.64 28.56 A13 13 0 0 1 3.44 12.64",
        "M3.44 12.64 A13 13 0 0 1 19.36 3.44",
    )
    ring = "".join(f'<path stroke="{color if sharing else RED}" d="{arc}"/>'
                   for color, arc in zip(SYNERGY_COLORS, arcs))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
      <g fill="none" stroke-width="2.6" stroke-linecap="round">{ring}</g>
      <path fill="{pointer}" d="M 11.5 9.3 L 21.4 17.1 L 17.1 17.7 L 19.2 22 L 16.9 23.1 L 14.8 18.8 L 11.5 22 Z"/>
    </svg>'''


def health(snapshot, prefs, state, error=None):
    running = snapshot["running"]
    paused = prefs.get("keys_paused", False)
    fresh = time.time() - state.get("updated", 0) < 4
    healthy = (running and not paused and not prefs.get("synergy_paused", False) and fresh
               and state.get("status") == "Mac-local app shortcuts" and state.get("applied_mode") in ("local", "mac")
               and not state.get("error") and not error)
    sharing_status = "Running" if running else "Paused" if prefs.get("synergy_paused") else "Stopped"
    keys_status = "Paused" if paused else "Ready" if healthy else "Waiting for Synergy" if not running else "Unavailable"
    return running, healthy, sharing_status, keys_status


class Tray:
    def __init__(self, app):
        self.app = app
        self.previous = None
        self.previous_sharing = None
        self.displayed_icon = None
        self.commands = set()
        self.lifecycle_error = None
        self.lifecycle_error_at = 0
        self.inspector = None
        self.closing = False
        self.tray = QSystemTrayIcon(app)
        self.menu = QMenu()
        self.summary = self.menu.addAction("Synergy: starting")
        self.summary.setEnabled(False)
        self.detail = self.menu.addAction("synergy-keys: pending")
        self.detail.setEnabled(False)
        self.menu.addSeparator()
        self.sharing = self.menu.addAction("Pause Synergy", self.toggle_sharing)
        self.keys = self.menu.addAction("Pause synergy-keys", self.toggle_keys)
        self.menu.addAction("Show Synergy configuration", lambda: self.command("synergy-keys", ["synergy", "config"]))
        self.menu.addSeparator()
        self.menu.addAction("Inspect shortcuts…", self.inspect_shortcuts)
        self.menu.addAction("Refresh screen detection", lambda: self.command("synergy-keys", ["refresh"]))
        self.menu.addAction("Show logs", lambda: self.command("alacritty", ["--hold", "-e", "synergy-keys", "logs"]))
        self.menu.addAction("Command help", lambda: self.command("synergy-keys", ["help"]))
        self.tray.setContextMenu(self.menu)
        primary_click_opens_menu(self.tray)
        self.icons = {(sharing, keys): svg_icon(icon_svg(sharing, keys))
                      for sharing in (False, True) for keys in (False, True)}
        self.tray.setIcon(self.icons[False, False])
        self.tray.show()
        self.timer = QTimer(app)
        self.timer.timeout.connect(self.tick)
        self.timer.start(500)
        app.aboutToQuit.connect(self.shutdown)
        self.tick()

    def toggle_keys(self):
        action = "resume" if controls.preferences().get("keys_paused", False) else "pause"
        self.command("synergy-keys", [action])

    def toggle_sharing(self):
        action = "pause" if synergy.processes()["running"] else "resume"
        self.command("synergy-keys", ["synergy", action])

    def inspect_shortcuts(self):
        from .inspector_ui import InspectorWindow
        if self.inspector is None:
            self.inspector = InspectorWindow()
        self.inspector.show()
        self.inspector.raise_()
        self.inspector.activateWindow()

    def command(self, program, arguments, lifecycle=False):
        if self.closing:
            return
        process = QProcess(self.app)
        self.commands.add(process)

        def finished(code, status):
            if code:
                error = bytes(process.readAllStandardError()).decode(errors="replace").strip()
                error = error or "Command failed; run synergy-keys logs"
                if lifecycle:
                    self.lifecycle_error = error
                    self.lifecycle_error_at = time.time()
                else:
                    self.tray.showMessage("Synergy", error, QSystemTrayIcon.MessageIcon.Warning)
            elif lifecycle or (program == "synergy-keys" and arguments[0] in ("refresh", "pause", "resume", "synergy")):
                self.lifecycle_error = None
            self.commands.discard(process)
            process.deleteLater()

        def failed(error):
            if error != QProcess.ProcessError.FailedToStart:
                return  # Crashes emit finished too.
            self.lifecycle_error = process.errorString()
            self.lifecycle_error_at = time.time()
            self.commands.discard(process)
            process.deleteLater()

        process.finished.connect(finished)
        process.errorOccurred.connect(failed)
        process.start(program, arguments)

    def shutdown(self):
        self.closing = True
        self.timer.stop()
        for process in tuple(self.commands):
            process.blockSignals(True)
            if process.state() != QProcess.ProcessState.NotRunning:
                process.kill()
                process.waitForFinished(1000)
        self.commands.clear()
        self.tray.hide()
        # The controller binds to this tray's unit; systemd resets mappings when
        # the tray exits, without a detached stop racing its replacement.

    def tick(self):
        snapshot = synergy.processes()
        prefs = controls.preferences()
        sharing_identity = (snapshot["running"], snapshot["session"], snapshot["cores"], prefs.get("synergy_paused", False))
        if sharing_identity != self.previous_sharing:
            if snapshot["running"] and prefs.get("synergy_paused", False):
                self.command("synergy-keys", ["synergy", "pause"], lifecycle=True)
            self.previous_sharing = sharing_identity
        enabled = snapshot["running"] and not prefs.get("keys_paused", False) and not prefs.get("synergy_paused", False)
        identity = (enabled, snapshot["session"], snapshot["cores"])
        if identity != self.previous:
            # Explicit resume can issue start concurrently. Join that start job;
            # restart only when an already-enabled sharing process changed.
            action = ("start" if self.previous is None or not self.previous[0] else "restart") if enabled else "stop"
            self.command("systemctl", ["--user", action, CONTROLLER_UNIT], lifecycle=True)
            self.previous = identity
        state = read_json(directory() / "state.json")
        if state.get("updated", 0) > self.lifecycle_error_at and health(snapshot, prefs, state)[1]:
            self.lifecycle_error = None
        sharing, keys, sharing_status, keys_status = health(snapshot, prefs, state, self.lifecycle_error)
        if (sharing, keys) != self.displayed_icon:
            self.tray.setIcon(self.icons[sharing, keys])
            self.displayed_icon = sharing, keys
        self.summary.setText(f"Synergy: {sharing_status}")
        self.detail.setText(f"synergy-keys: {keys_status}")
        self.sharing.setText("Pause Synergy" if sharing else "Resume Synergy")
        self.keys.setText("Resume synergy-keys" if prefs.get("keys_paused", False) else "Pause synergy-keys")
        detail = self.lifecycle_error or describe(state)
        self.tray.setToolTip(f"Synergy: {sharing_status}\nsynergy-keys: {keys_status}\n{detail}")


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("synergy")
    app.setApplicationDisplayName("Synergy")
    app.setQuitOnLastWindowClosed(False)
    tray = Tray(app)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *args: app.quit())
    app.exec()
    del tray


if __name__ == "__main__":
    main()
