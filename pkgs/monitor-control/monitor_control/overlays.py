"""Supervise a bounded, pipe-owned QML worker for each visible output."""

import json
import sys

from PyQt6.QtCore import QObject, QProcess, QProcessEnvironment, QTimer, pyqtSignal


class Overlays(QObject):
    failed = pyqtSignal(str, str)
    changed = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.workers = {}
        self.retiring = set()

    def update(self, output, covered, label=False):
        worker = self.workers.get(output.name)
        if worker is None:
            if not covered and not label:
                return
            process = QProcess(self)
            environment = QProcessEnvironment.systemEnvironment()
            environment.insert("QT_QPA_PLATFORM", "wayland")
            # Static rectangles/text need no EGL context or GPU-specific setup.
            environment.insert("QT_QUICK_BACKEND", "software")
            process.setProcessEnvironment(environment)
            process.setProcessChannelMode(QProcess.ProcessChannelMode.ForwardedErrorChannel)
            worker = {"process": process, "covered": covered, "labeling": label,
                      "label_generation": int(label),
                      "ready": False, "rendered": False, "screen": None,
                      "buffer": b"", "title": output.title}
            self.workers[output.name] = worker
            process.readyReadStandardOutput.connect(lambda: self.read(output.name, worker))
            process.started.connect(lambda: self.started(output.name, worker))
            process.finished.connect(lambda code, status: self.exited(output.name, worker, code))
            process.errorOccurred.connect(lambda error: self.error(output.name, worker, process.errorString()))
            process.start(sys.executable, ["-m", "monitor_control.worker", output.name])
            QTimer.singleShot(4000, lambda: self.check_ready(output.name, worker))
        else:
            worker.update(covered=covered, title=output.title)
            if label:
                worker["labeling"] = True
                worker["label_generation"] += 1
            if worker["process"].state() == QProcess.ProcessState.Running:
                self.send(worker, label)

    def started(self, name, worker):
        if self.workers.get(name) is not worker:
            return
        if not worker["covered"] and not worker["labeling"]:
            self.stop(name)
            return
        self.send(worker, worker["labeling"])

    @staticmethod
    def send(worker, label=False):
        worker["process"].write(json.dumps({"covered": worker["covered"], "label": label,
                                           "label_generation": worker["label_generation"],
                                           "title": worker["title"]}).encode() + b"\n")

    def read(self, name, worker):
        worker["buffer"] += bytes(worker["process"].readAllStandardOutput())
        if len(worker["buffer"]) > 65536:
            self.error(name, worker, "Overlay response too large")
            return
        while b"\n" in worker["buffer"]:
            line, worker["buffer"] = worker["buffer"].split(b"\n", 1)
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if event.get("ready"):
                worker["ready"] = True
            if event.get("rendered"):
                worker["rendered"] = True
                worker["screen"] = event["screen"]
            if event.get("label_finished") and event.get("label_generation") == worker["label_generation"]:
                worker["labeling"] = False
            if event.get("idle"):
                if not worker["covered"] and not worker["labeling"] and self.workers.get(name) is worker:
                    self.stop(name)
            if event.get("error"):
                self.error(name, worker, event["error"])
            self.changed.emit()

    def check_ready(self, name, worker):
        if self.workers.get(name) is worker and not worker["rendered"]:
            self.error(name, worker, "Overlay did not render")

    def error(self, name, worker, message):
        if self.workers.get(name) is worker:
            self.stop(name)
            self.failed.emit(name, message)

    def exited(self, name, worker, code):
        if self.workers.get(name) is worker:
            del self.workers[name]
            self.failed.emit(name, f"Overlay exited ({code})")
        self.retiring.discard(worker["process"])
        worker["process"].deleteLater()
        self.changed.emit()

    def stop(self, name):
        worker = self.workers.pop(name, None)
        if worker is None:
            return
        process = worker["process"]
        if process.state() == QProcess.ProcessState.NotRunning:
            process.deleteLater()
            return
        self.retiring.add(process)
        process.closeWriteChannel()
        QTimer.singleShot(1000, lambda: process.kill() if process in self.retiring else None)

    def reconcile(self, outputs, blacked):
        eligible = {item.name for item in outputs if item.active}
        for name in list(self.workers):
            if name not in eligible:
                self.stop(name)
        for output in outputs:
            if output.active:
                self.update(output, output.name in blacked)

    def close(self):
        for name in list(self.workers):
            self.stop(name)
        for process in list(self.retiring):
            process.kill()
        for process in list(self.retiring):
            process.waitForFinished(1000)

    def snapshot(self):
        return {name: {key: worker[key] for key in ("ready", "rendered", "screen", "covered", "labeling")}
                for name, worker in self.workers.items()}
