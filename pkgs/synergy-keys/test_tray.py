"""Offscreen tests never dispatch desktop input or real service controls."""

import os
import time
import unittest
from unittest.mock import patch

try:
    from PyQt6.QtWidgets import QApplication
    from synergy_keys.tray import SYNERGY_COLORS, WHITE, RED, Tray, health, icon_svg
    HAS_QT = True
except ImportError:
    HAS_QT = False

SAFE_QT = (os.environ.get("QT_QPA_PLATFORM") == "offscreen" and not os.environ.get("DISPLAY")
           and not os.environ.get("WAYLAND_DISPLAY")
           and os.environ.get("DBUS_SESSION_BUS_ADDRESS") == "unix:path=/nonexistent")


@unittest.skipUnless(HAS_QT and SAFE_QT, "requires an isolated offscreen Qt environment")
class TrayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        with patch.object(Tray, "tick"):
            self.tray = Tray(self.app)
        self.tray.timer.stop()
        self.addCleanup(self.tray.shutdown)
        self.state = {"status": "Mac-local app shortcuts", "applied_mode": "local", "updated": time.time(), "error": None}
        self.snapshot = {"running": True, "session": [1, "start"], "cores": [[2, "start"]]}

    def test_local_mode_can_be_healthy_and_pauses_are_independent(self):
        self.assertEqual(health(self.snapshot, {}, self.state)[:2], (True, True))
        self.assertEqual(health(self.snapshot, {"keys_paused": True}, self.state)[:2], (True, False))
        self.assertEqual(health({**self.snapshot, "running": False}, {}, self.state)[:2], (False, False))
        self.assertEqual(health(self.snapshot, {}, {**self.state, "updated": 0})[:2], (True, False))
        self.assertEqual(health(self.snapshot, {}, {**self.state, "applied_mode": None})[:2], (True, False))

    def test_four_icon_states_have_independent_colors_and_fractional_sizes(self):
        for sharing in (False, True):
            for keys in (False, True):
                svg = icon_svg(sharing, keys)
                for color in SYNERGY_COLORS:
                    self.assertEqual(f'stroke="{color}"' in svg, sharing)
                self.assertIn(f'fill="{WHITE if keys else RED}"', svg)
                self.assertEqual('stroke="' + RED + '"' in svg, not sharing)
                sizes = {size.width() for size in self.tray.icons[sharing, keys].availableSizes()}
                self.assertTrue({25, 28, 30, 64}.issubset(sizes))

    def test_menu_pause_commands_target_separate_components(self):
        with patch("synergy_keys.tray.controls.preferences", return_value={}), patch("synergy_keys.tray.synergy.processes", return_value=self.snapshot), patch.object(self.tray, "command") as command:
            self.tray.keys.trigger()
            command.assert_called_with("synergy-keys", ["pause"])
            self.tray.sharing.trigger()
            command.assert_called_with("synergy-keys", ["synergy", "pause"])
        with patch("synergy_keys.tray.controls.preferences", return_value={"keys_paused": True}), patch("synergy_keys.tray.synergy.processes", return_value={"running": False}), patch.object(self.tray, "command") as command:
            self.tray.keys.trigger()
            command.assert_called_with("synergy-keys", ["resume"])
            self.tray.sharing.trigger()
            command.assert_called_with("synergy-keys", ["synergy", "resume"])

    def test_paused_keys_are_not_restarted_and_icon_not_reexported_each_tick(self):
        with patch("synergy_keys.tray.controls.preferences", return_value={"keys_paused": True}), patch("synergy_keys.tray.synergy.processes", return_value=self.snapshot), patch("synergy_keys.tray.read_json", return_value=self.state), patch.object(self.tray, "command") as command, patch.object(self.tray.tray, "setIcon") as icon:
            self.tray.tick()
            self.tray.tick()
        command.assert_called_once_with("systemctl", ["--user", "stop", "synergy-keys-controller.service"], lifecycle=True)
        icon.assert_called_once()
        self.assertTrue(self.tray.tray.isVisible())

    def test_saved_sharing_pause_is_reapplied_on_native_restart(self):
        with patch("synergy_keys.tray.controls.preferences", return_value={"synergy_paused": True}), patch("synergy_keys.tray.synergy.processes", return_value=self.snapshot), patch("synergy_keys.tray.read_json", return_value=self.state), patch.object(self.tray, "command") as command:
            self.tray.tick()
            self.tray.tick()
        self.assertIn((("synergy-keys", ["synergy", "pause"]), {"lifecycle": True}), command.call_args_list)

    def test_resume_transition_joins_start_instead_of_cancelling_it_with_restart(self):
        with patch("synergy_keys.tray.controls.preferences", return_value={"keys_paused": True}) as prefs, patch("synergy_keys.tray.synergy.processes", return_value=self.snapshot), patch("synergy_keys.tray.read_json", return_value=self.state), patch.object(self.tray, "command") as command:
            self.tray.tick()
            command.reset_mock()
            prefs.return_value = {"keys_paused": False}
            self.tray.tick()
        command.assert_called_once_with("systemctl", ["--user", "start", "synergy-keys-controller.service"], lifecycle=True)

    def test_new_healthy_controller_state_clears_an_older_lifecycle_error(self):
        self.tray.lifecycle_error = "old start failed"
        self.tray.lifecycle_error_at = self.state["updated"] - 1
        with patch("synergy_keys.tray.controls.preferences", return_value={}), patch("synergy_keys.tray.synergy.processes", return_value=self.snapshot), patch("synergy_keys.tray.read_json", return_value=self.state), patch.object(self.tray, "command"):
            self.tray.tick()
        self.assertIsNone(self.tray.lifecycle_error)
        self.assertEqual(self.tray.displayed_icon, (True, True))

    def test_shutdown_kills_pending_checks_without_detached_service_commands(self):
        self.tray.command("/bin/sh", ["-c", "sleep 30"])
        self.tray.shutdown()
        self.assertFalse(self.tray.commands)
        self.assertFalse(self.tray.tray.isVisible())


if __name__ == "__main__":
    unittest.main()
