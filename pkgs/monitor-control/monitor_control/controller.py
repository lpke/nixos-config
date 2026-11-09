import fcntl
import signal
import sys

from PyQt6.QtCore import QTimer
from PyQt6.QtWidgets import QApplication

from .ipc import Server
from .outputs import connected_outputs
from .overlays import Overlays
from .paths import runtime_directory, settings_file
from .state import State
from .tray import Tray


class Controller:
    def __init__(self, app):
        self.app = app
        self.state = State(settings_file())
        self.overlays = Overlays()
        self.overlays.failed.connect(self.failed)
        self.tray = Tray(self.state, self.from_menu)
        self.server = Server(runtime_directory() / "controller.sock", self.dispatch)
        self.timer = QTimer()
        self.timer.timeout.connect(self.refresh)
        self.timer.start(3000)
        self.app.screenAdded.connect(lambda _: self.refresh())
        self.app.screenRemoved.connect(lambda _: self.refresh())
        self.app.aboutToQuit.connect(self.close)

    def refresh(self):
        self.state.refresh(connected_outputs(self.app))
        self.overlays.reconcile(self.state.outputs.values(), self.state.blacked)
        if hasattr(self, "tray"):
            self.tray.sync()

    def dispatch(self, command, target=None):
        self.refresh()
        if command == "toggle":
            self.state.toggle(target if target is not None else self.state.target)
            self.overlays.reconcile(self.state.outputs.values(), self.state.blacked)
        elif command == "select":
            self.state.select(target)
        elif command == "label":
            for output in self.state.outputs.values():
                if output.active:
                    self.overlays.update(output, output.name in self.state.blacked, label=True)
        elif command == "restore":
            self.state.blacked.clear()
            self.overlays.reconcile(self.state.outputs.values(), self.state.blacked)
        elif command == "quit":
            QTimer.singleShot(0, self.app.quit)
        elif command not in {"launch", "status", "refresh"}:
            raise ValueError(f"Unknown command: {command}")
        if hasattr(self, "tray"):
            self.tray.sync()
        return {"ok": True, "running": True, **self.state.snapshot(),
                "overlays": self.overlays.snapshot()}

    def from_menu(self, command, target=None):
        try:
            return self.dispatch(command, target)
        except (ValueError, OSError) as error:
            self.tray.sync()
            self.tray.error(str(error))

    def failed(self, name, message):
        self.state.blacked.discard(name)
        self.tray.sync()
        self.tray.error(f"{name}: {message}")

    def close(self):
        self.server.close()
        self.overlays.close()
        self.tray.icon.hide()


def main():
    with (runtime_directory() / "controller.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        app = QApplication(sys.argv)
        app.setApplicationName("Monitor control")
        app.setDesktopFileName("monitor-control")
        app.setQuitOnLastWindowClosed(False)
        controller = Controller(app)
        signal.signal(signal.SIGTERM, lambda *_: app.quit())
        signal.signal(signal.SIGINT, lambda *_: app.quit())
        heartbeat = QTimer()
        heartbeat.timeout.connect(lambda: None)
        heartbeat.start(200)
        result = app.exec()
        del controller
        return result


if __name__ == "__main__":
    sys.exit(main())
