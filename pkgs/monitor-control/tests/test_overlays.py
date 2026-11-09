import json
import unittest
from unittest.mock import patch

from PyQt6.QtWidgets import QApplication

from monitor_control.overlays import Overlays
from monitor_control.state import Output

app = QApplication.instance() or QApplication([])


class OverlayRaceTests(unittest.TestCase):
    def setUp(self):
        self.overlays = Overlays()
        self.addCleanup(self.overlays.close)
        self.output = Output("DP-1", "Samsung (DP-1)")
        self.errors = []
        self.overlays.failed.connect(lambda *error: self.errors.append(error))
        # Hold actual process startup so cancellation and queued events can be
        # delivered in a deterministic order without mapping any surface.
        start = patch("monitor_control.overlays.QProcess.start")
        start.start()
        self.addCleanup(start.stop)

    def test_cancel_before_start_retires_without_readiness_warning(self):
        self.overlays.update(self.output, True)
        worker = self.overlays.workers[self.output.name]
        self.overlays.update(self.output, False)
        worker["process"].started.emit()
        self.overlays.check_ready(self.output.name, worker)
        self.assertNotIn(self.output.name, self.overlays.workers)
        self.assertEqual(self.errors, [])

    def test_queued_old_label_completion_cannot_dismiss_repeat(self):
        self.overlays.update(self.output, False, label=True)
        worker = self.overlays.workers[self.output.name]
        original = worker["label_generation"]
        self.overlays.update(self.output, False, label=True)
        current = worker["label_generation"]
        self.assertGreater(current, original)

        def deliver(generation):
            events = [{"label_finished": True, "label_generation": generation}, {"idle": True}]
            data = b"".join(json.dumps(event).encode() + b"\n" for event in events)
            with patch.object(worker["process"], "readAllStandardOutput", return_value=data):
                self.overlays.read(self.output.name, worker)

        deliver(original)
        self.assertIs(self.overlays.workers[self.output.name], worker)
        self.assertTrue(worker["labeling"])
        deliver(current)
        self.assertNotIn(self.output.name, self.overlays.workers)
        self.assertEqual(self.errors, [])
