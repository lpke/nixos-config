"""One QML surface per output, owned through the controller's stdin pipe."""

import json
import os
import signal
import sys

from PyQt6.QtCore import QSocketNotifier, QTimer
from PyQt6.QtGui import QGuiApplication

from .surface import create_surface


def emit(**event):
    print(json.dumps(event), flush=True)


def main():
    app = QGuiApplication(sys.argv[:1])
    app.setQuitOnLastWindowClosed(False)
    name = sys.argv[1]
    screen = next((item for item in app.screens() if item.name() == name), None)
    if screen is None:
        raise RuntimeError(f"Monitor unavailable: {name}")
    engine, window = create_surface(screen)
    app.screenRemoved.connect(lambda removed: app.quit() if removed is screen else None)
    screen.geometryChanged.connect(lambda geometry: window.resize(geometry.size()))
    signal.signal(signal.SIGTERM, lambda *_: app.quit())
    heartbeat = QTimer()
    heartbeat.timeout.connect(lambda: None)
    heartbeat.start(200)
    label_generation = 0

    def finished():
        emit(label_finished=True, output=name, label_generation=label_generation)

    window.labelFinished.connect(finished)
    window.surfaceIdle.connect(lambda: emit(idle=True, output=name))
    window.frameSwapped.connect(lambda: emit(rendered=True, output=name,
                                             screen=window.screen().name(),
                                             scale=window.devicePixelRatio()))
    pending = bytearray()

    def read():
        nonlocal label_generation
        chunk = os.read(sys.stdin.fileno(), 65536)
        if not chunk:
            app.quit()
            return
        pending.extend(chunk)
        if len(pending) > 65536:
            app.exit(1)
            return
        while b"\n" in pending:
            line, _, rest = pending.partition(b"\n")
            pending[:] = rest
            try:
                command = json.loads(line)
                window.setProperty("monitorName", command.get("title", name))
                window.setProperty("covered", bool(command.get("covered")))
                if command.get("label"):
                    label_generation = command["label_generation"]
                    window.showLabel()
                emit(updated=True, output=name, covered=window.property("covered"),
                     labeling=window.property("labeling"), screen=window.screen().name())
            except (ValueError, TypeError) as error:
                emit(error=str(error))

    notifier = QSocketNotifier(sys.stdin.fileno(), QSocketNotifier.Type.Read)
    notifier.activated.connect(read)
    emit(ready=True, output=name, screen=window.screen().name())
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
