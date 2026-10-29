"""Run only with a disconnected, offscreen Qt session. No desktop input."""

import os
from pathlib import Path
import unittest
from unittest.mock import patch

try:
    from PyQt6.QtCore import Qt
    from PyQt6.QtTest import QSignalSpy, QTest
    from PyQt6.QtWidgets import QApplication
    from synergy_keys.inspector_ui import InspectorWindow
    from synergy_keys.inspector_view import render
    from synergy_keys.inspector_search import Catalog
    from synergy_keys.inspector_sources import Sources
    from synergy_keys.inspector import trace
    HAS_QT = True
except ImportError:
    HAS_QT = False

SAFE_QT = (os.environ.get("QT_QPA_PLATFORM") == "offscreen" and not os.environ.get("DISPLAY")
           and not os.environ.get("WAYLAND_DISPLAY")
           and os.environ.get("DBUS_SESSION_BUS_ADDRESS") == "unix:path=/nonexistent")
ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(HAS_QT and SAFE_QT, "requires PyQt6 and an isolated offscreen Qt environment")
class InspectorUiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setQuitOnLastWindowClosed(False)
        cls.sources = Sources(ROOT)
        cls.catalogs = {device: Catalog(cls.sources, device) for device in ["Keyboard", "Logitech G903"]}

    def setUp(self):
        self.window = InspectorWindow(catalogs=self.catalogs)
        self.window.show()
        self.app.processEvents()
        self.addCleanup(self.window.close)

    def test_search_select_and_device_switch(self):
        self.window.query.setText("ThUmB - L")
        self.assertEqual(self.window.results.count(), 1)
        details = self.window.details.toPlainText()
        for text in ["ThUmB - L", "Ctrl+L", "Cmd+L", "Alacritty", "iTerm2", "missing/empty", "synergy-keymap.json", "synergy-keys.lua"]:
            self.assertIn(text, details)
        self.window.query.setText("grw windw")
        self.assertEqual(self.window.results.count(), 2)
        self.window.results.setCurrentRow(1)
        self.assertIn("Grow window", self.window.details.toPlainText())
        self.window.query.setText("meta+m")
        self.window.device.setCurrentText("Logitech G903")
        self.assertNotIn("Open a new Alacritty", self.window.details.toPlainText())
        self.window.query.setText("thisdoesnotexist")
        self.assertEqual(self.window.results.count(), 0)
        self.assertIn("No matches", self.window.details.toPlainText())

    def test_capture_consumes_local_shortcut_and_tab_without_closing(self):
        for key, modifiers, expected in [
            (Qt.Key.Key_W, Qt.KeyboardModifier.ControlModifier, "Ctrl+W"),
            (Qt.Key.Key_Tab, Qt.KeyboardModifier.ControlModifier, "Ctrl+Tab"),
            (Qt.Key.Key_C, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier, "Ctrl+Shift+C"),
        ]:
            self.window.record.setChecked(True)
            QTest.keyClick(self.window.query, key, modifiers)
            self.assertEqual(self.window.query.text(), expected)
            self.assertFalse(self.window.record.isChecked())
            self.assertTrue(self.window.isVisible())

    def test_html_escaping_and_real_source_locations(self):
        html = render(trace(self.sources, "thumb+l"), '<script>alert("x")</script>')
        self.assertNotIn("<script>", html)
        self.assertIn("&lt;script&gt;", html)
        self.assertIn((ROOT / "user/xremap/synergy-keymap.json").as_uri(), html)

    def test_refresh_reads_sources_and_failure_clears_old_results(self):
        self.window.load()
        self.assertFalse(self.window.reload.isEnabled())
        spy = QSignalSpy(self.window.loader.finished)
        self.assertTrue(spy.wait(10000))
        self.assertTrue(self.window.reload.isEnabled())
        self.assertGreater(self.window.results.count(), 0)
        self.window.failed("missing source")
        self.assertEqual(self.window.results.count(), 0)
        self.assertEqual(self.window.details.toPlainText(), "")
        self.assertIn("missing source", self.window.status.text())

    def test_close_during_refresh_finishes_worker_without_service_calls(self):
        self.window.load()
        self.window.close()
        self.assertFalse(self.window.isVisible())
        spy = QSignalSpy(self.window.loader.finished)
        if self.window.loader.isRunning():
            self.assertTrue(spy.wait(10000))

    def test_hidden_standalone_window_quits_after_its_worker_finishes(self):
        self.window.hide()
        self.app.setQuitOnLastWindowClosed(True)
        try:
            with patch.object(QApplication, "quit") as quit_app:
                self.window.finish_close()
                quit_app.assert_called_once()
        finally:
            self.app.setQuitOnLastWindowClosed(False)

    def test_tray_entry_opens_and_reuses_inspector_without_lifecycle_changes(self):
        from synergy_keys.tray import Tray
        # Never exercise the real tray lifecycle: stopping the tray normally
        # stops the controller. Both methods stay mocked through destruction.
        with patch.object(Tray, "tick"), patch.object(Tray, "stop_controller"), \
             patch("synergy_keys.tray.QProcess") as process, \
             patch("synergy_keys.inspector_ui.InspectorWindow", return_value=self.window) as constructor:
            tray = Tray(self.app)
            tray.timer.stop()
            action = next(a for a in tray.menu.actions() if a.text() == "Inspect shortcuts…")
            action.trigger()
            action.trigger()
            constructor.assert_called_once()
            process.assert_not_called()
            tray.tray.hide()
            del tray


if __name__ == "__main__":
    unittest.main()
