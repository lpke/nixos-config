"""Independent status, transport dispatch, HiDPI publishing and clean teardown."""

import sys
from itertools import product
from pathlib import Path
import unittest
from unittest.mock import patch
from xml.etree import ElementTree

from PyQt6.QtCore import QEventLoop, QTimer
from PyQt6.QtWidgets import QApplication

from t3_tray.tray import MENU_RIGHT_GUTTER, Tray, TRANSPORTS
from t3_tray.icons import AQUA, RED, icon_svg
from tray_icon import ICON_SIZES, svg_icon


class TrayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setQuitOnLastWindowClosed(False)

    def setUp(self):
        with patch.object(Tray, "tick"):
            self.tray = Tray(self.app)
        self.tray.timer.stop()
        self.addCleanup(self.tray.shutdown)

    def test_eight_combinations_color_each_component_independently(self):
        for tailscale, review, ssh in product((False, True), repeat=3):
            with self.subTest(tailscale=tailscale, review=review, ssh=ssh):
                for key, connected in zip(TRANSPORTS, (tailscale, review, ssh)):
                    self.tray.update(key, {"connected": connected, "active": connected})
                self.assertEqual(self.tray.icon_state, (tailscale, review, ssh))
                self.assertEqual(self.tray.tray.icon().cacheKey(), self.tray.icons[tailscale, review, ssh].cacheKey())
                svg = ElementTree.fromstring(icon_svg(tailscale, review, ssh))
                upper, lower, right, glyph = list(svg)
                for arc, connected in zip((upper, lower, right), (tailscale, review, ssh)):
                    self.assertEqual(arc.get("stroke"), AQUA if connected else RED)
                self.assertIsNone(upper.get("stroke-dasharray"))
                self.assertIsNone(lower.get("stroke-dasharray"))
                self.assertIsNotNone(right.get("stroke-dasharray"))

    def test_same_state_does_not_republish_large_icon_arrays(self):
        with patch.object(self.tray.tray, "setIcon") as publish:
            self.tray.display()
            self.tray.update("ssh", {"connected": False, "status": "Offline"})
            publish.assert_not_called()
            self.tray.update("ssh", {"connected": True})
            self.assertEqual(publish.call_count, 1)

    def test_each_submenu_dispatches_only_its_transport(self):
        with patch.object(self.tray, "command") as command:
            for key, (_, program) in TRANSPORTS.items():
                menu = self.tray.actions[key]["menu"]
                for label, argument in [("Start", "start"), ("Pause", "stop"), ("Help", "help")]:
                    action = next(action for action in menu.actions() if action.text() == label)
                    action.setEnabled(True)
                    action.trigger()
                    command.assert_called_with(program, [argument])
                if key != "review":
                    next(a for a in menu.actions() if a.text() == "Show logs").trigger()
                    command.assert_called_with("alacritty", ["--hold", "-e", program, "logs"])

    def test_shared_quit_only_exits_ui(self):
        with patch.object(self.app, "quit") as quit, patch.object(Tray, "tick"):
            tray = Tray(self.app)
            self.addCleanup(tray.shutdown)
            with patch.object(tray, "command") as command:
                next(a for a in tray.menu.actions() if a.text() == "Quit tray").trigger()
            quit.assert_called_once()
            command.assert_not_called()

    def test_polling_is_independent_and_never_duplicates_pending_checks(self):
        with patch.object(self.tray, "command") as command:
            self.tray.tick()
            self.assertEqual(command.call_count, 3)
            self.tray.tick()
            self.assertEqual(command.call_count, 3)
            self.tray.polling.discard("ssh")
            self.tray.tick()
            self.assertEqual(command.call_count, 4)
            command.assert_called_with("t3-ssh", ["status", "--json"], polling="ssh")

    def test_pause_and_start_states_do_not_leak_between_transports(self):
        self.tray.update("tailscale", {"connected": True, "active": True})
        self.tray.update("ssh", {"connected": False, "active": False})
        self.assertTrue(self.tray.actions["tailscale"]["pause"].isEnabled())
        self.assertFalse(self.tray.actions["tailscale"]["start"].isEnabled())
        self.assertFalse(self.tray.actions["ssh"]["pause"].isEnabled())
        self.assertTrue(self.tray.actions["ssh"]["start"].isEnabled())

    def test_poll_result_and_malformed_output_are_local_to_one_transport(self):
        for output in ['{"connected":true,"status":"Connected"}', '[]', 'invalid']:
            with self.subTest(output=output):
                self.tray.polling.add("ssh")
                self.tray.command(sys.executable, ["-c", "print(" + repr(output) + ")"], polling="ssh")
                process = next(iter(self.tray.commands))
                self.assertTrue(process.waitForFinished(3000))
                self.assertFalse(self.tray.polling)
                self.assertFalse(self.tray.commands)
                self.assertFalse(self.tray.states["tailscale"].get("connected"))
                self.assertEqual(self.tray.states["ssh"].get("connected", False), output.startswith('{'))

    def test_failed_to_start_releases_poll_slot(self):
        self.tray.polling.add("ssh")
        self.tray.command("/no/such/t3-helper", [], polling="ssh")
        process = next(iter(self.tray.commands))
        self.assertFalse(process.waitForStarted(1000))
        self.assertFalse(self.tray.polling)
        self.assertFalse(self.tray.commands)
        self.assertEqual(self.tray.states["ssh"]["status"], "Connection error")

    def test_missing_review_helper_is_unavailable_without_affecting_connections(self):
        self.tray.update("ssh", {"connected": True, "active": True})
        self.tray.polling.add("review")
        self.tray.command("/no/such/git-review-launcher", ["status", "--json"], polling="review")
        process = next(iter(self.tray.commands))
        self.assertFalse(process.waitForStarted(1000))
        self.assertFalse(self.tray.polling)
        self.assertEqual(self.tray.states["review"]["status"], "Helper unavailable")
        self.assertFalse(self.tray.actions["review"]["start"].isEnabled())
        self.assertFalse(self.tray.actions["review"]["pause"].isEnabled())
        self.assertTrue(self.tray.states["ssh"]["connected"])

    def test_old_or_malformed_review_status_disables_start_and_releases_poll(self):
        for output in ('old launcher output', '{}', '{"connected":"yes","active":true}'):
            with self.subTest(output=output):
                self.tray.polling.add("review")
                self.tray.command(sys.executable, ["-c", "print(" + repr(output) + ")"], polling="review")
                process = next(iter(self.tray.commands))
                self.assertTrue(process.waitForFinished(3000))
                self.assertFalse(self.tray.polling)
                self.assertFalse(self.tray.actions["review"]["start"].isEnabled())
                self.assertEqual(self.tray.states["review"]["status"], "Helper unavailable")

    def test_hung_review_status_times_out_without_blocking_other_checks(self):
        self.tray.polling.add("review")
        self.tray.command(sys.executable, ["-c", "import time; time.sleep(60)"], polling="review")
        process = next(iter(self.tray.commands))
        self.assertTrue(process.waitForStarted(1000))
        process.findChild(QTimer).timeout.emit()
        self.assertTrue(process.waitForFinished(3000))
        self.assertFalse(self.tray.polling)
        self.assertEqual(self.tray.states["review"]["detail"], "Git review status timed out.")

    def test_missing_review_dependencies_still_allow_pausing_an_active_listener(self):
        self.tray.update("review", {"connected": False, "active": True, "available": False,
                                    "status": "Dependency missing", "detail": "Neovim is unavailable"})
        self.assertTrue(self.tray.actions["review"]["pause"].isEnabled())
        self.assertFalse(self.tray.actions["review"]["start"].isEnabled())

    def test_unhealthy_review_listener_can_be_repaired_with_start(self):
        self.tray.update("review", {"connected": False, "active": True, "available": True,
                                    "status": "stopped", "detail": "Authorisation key is missing"})
        self.assertTrue(self.tray.actions["review"]["start"].isEnabled())
        self.assertTrue(self.tray.actions["review"]["pause"].isEnabled())

    def test_shutdown_stops_pending_checks_and_prevents_further_work(self):
        self.tray.polling.add("ssh")
        self.tray.command(sys.executable, ["-c", "import time; time.sleep(60)"], polling="ssh")
        process = next(iter(self.tray.commands))
        self.assertTrue(process.waitForStarted(1000))
        self.tray.shutdown()
        self.assertEqual(process.state(), process.ProcessState.NotRunning)
        self.assertFalse(self.tray.commands)
        self.assertFalse(self.tray.polling)
        self.assertFalse(self.tray.timer.isActive())
        self.tray.tick()
        self.assertFalse(self.tray.commands)

    def test_full_submenu_labels_keep_a_right_gutter_before_native_arrows(self):
        labels = [action.text() for action in self.tray.menu.actions() if action.menu()]
        self.assertEqual(labels, [title + MENU_RIGHT_GUTTER for title, _ in TRANSPORTS.values()])
        self.assertTrue(all(label.endswith("\u00a0" * 3) for label in labels))

    def test_icons_expose_original_svg_and_fractional_scale_fallbacks(self):
        for icon in self.tray.icons.values():
            source = Path(icon.name())
            self.assertTrue(source.is_absolute() and source.suffix == ".svg" and source.is_file())
            self.assertIn('viewBox="0 0 32 32"', source.read_text())
            self.assertEqual({size.width() for size in icon.availableSizes()}, set(ICON_SIZES))
            for size in (22, 25, 28, 30, 44, 48, 64):
                pixmap = icon.pixmap(size, size)
                self.assertEqual((pixmap.width(), pixmap.height()), (size, size))
                self.assertFalse(pixmap.isNull())
        with self.assertRaises(ValueError):
            svg_icon("not an SVG")


if __name__ == "__main__":
    unittest.main()
