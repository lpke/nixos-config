"""Qt menu and icon checks; run with QT_QPA_PLATFORM=offscreen."""

import unittest
import sys
from unittest.mock import patch

try:
    from PyQt6.QtWidgets import QApplication
    from t3_ssh.tray import Tray
except ImportError:
    QApplication = None

try:
    from t3_tailscale.tray import Tray as TailscaleTray
except ImportError:
    TailscaleTray = None


@unittest.skipIf(QApplication is None, "Requires package Python with PyQt6")
class TrayTests(unittest.TestCase):
    factory = Tray if QApplication else None
    helper = "t3-ssh"
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setQuitOnLastWindowClosed(False)

    def setUp(self):
        with patch.object(self.factory, "tick"):
            self.tray = self.factory(self.app)
        self.tray.timer.stop()
        self.addCleanup(self.tray.tray.hide)
        self.addCleanup(self.tray.shutdown)

    def test_shutdown_stops_pending_checks_before_qt_deletes_them(self):
        self.tray.command(["-c", "import time; time.sleep(60)"], program=sys.executable, polling=True)
        process = next(iter(self.tray.commands))
        self.assertTrue(process.waitForStarted(1000))
        self.tray.shutdown()
        self.assertEqual(process.state(), process.ProcessState.NotRunning)
        self.assertFalse(self.tray.commands)
        self.assertFalse(self.tray.timer.isActive())
        self.tray.tick()
        self.assertFalse(self.tray.commands)

    def test_menu_controls_have_distinct_pause_and_quit_actions(self):
        self.assertEqual(self.tray.program, self.helper)
        with patch.object(self.tray, "command") as command:
            for text, argument in [("Start", "start"), ("Pause", "stop"), ("Help", "help"), ("Quit", "quit")]:
                next(a for a in self.tray.menu.actions() if a.text() == text).trigger()
                command.assert_called_with([argument])

    def test_icons_load_and_follow_connection_health(self):
        for icon in self.tray.icons.values():
            self.assertFalse(icon.isNull())
        self.tray.display({"connected": True, "active": True, "status": "Connected", "detail": "Mac"})
        self.assertEqual(self.tray.tray.icon().cacheKey(), self.tray.icons["connected"].cacheKey())
        self.assertTrue(self.tray.pause.isEnabled())
        self.tray.display({"connected": False, "active": False, "status": "Paused"})
        self.assertEqual(self.tray.tray.icon().cacheKey(), self.tray.icons["error"].cacheKey())
        self.assertTrue(self.tray.start.isEnabled())


@unittest.skipIf(TailscaleTray is None, "Requires the Tailscale tray module")
class TailscaleTrayTests(TrayTests):
    factory = TailscaleTray
    helper = "t3-tailscale"


if __name__ == "__main__":
    unittest.main()
