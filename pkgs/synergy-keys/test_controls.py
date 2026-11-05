"""No live D-Bus events, input, Flatpak commands or service changes."""

from contextlib import redirect_stdout
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import call, patch

from synergy_keys import cli, controls


class ControlTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name, value in (("preferences_path", self.root / "state/controls.json"), ("directory", self.root)):
            mock = patch.object(controls, name, return_value=value)
            mock.start()
            self.addCleanup(mock.stop)

    def test_keys_pause_persists_and_stops_only_controller(self):
        with patch.object(controls, "command") as command:
            controls.control("keys", "pause")
        self.assertTrue(controls.preferences()["keys_paused"])
        command.assert_called_once_with("systemctl", "--user", "stop", controls.CONTROLLER_UNIT)

    def test_resume_keys_while_synergy_stopped_arms_next_session(self):
        controls.set_preference("keys_paused", True)
        with patch.object(controls.synergy, "processes", return_value={"running": False}), patch.object(controls, "command") as command:
            controls.control("keys", "resume")
        self.assertFalse(controls.preferences()["keys_paused"])
        command.assert_not_called()

    def test_resume_keys_starts_controller_without_touching_synergy(self):
        with patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "command") as command:
            controls.control("keys", "resume")
        self.assertEqual(command.call_args_list, [call("systemctl", "--user", "reset-failed", controls.CONTROLLER_UNIT),
                                                 call("systemctl", "--user", "start", controls.CONTROLLER_UNIT)])

    def test_failed_keys_pause_restores_preference(self):
        with patch.object(controls, "command", side_effect=subprocess.CalledProcessError(1, "systemctl")):
            with self.assertRaises(subprocess.SubprocessError):
                controls.control("keys", "pause")
        self.assertFalse(controls.preferences()["keys_paused"])

    def test_resume_loads_collected_controller_even_if_reset_failed_finds_no_unit(self):
        controls.set_preference("keys_paused", True)
        with patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "command", side_effect=[subprocess.CalledProcessError(1, "systemctl", stderr="Unit not loaded"), ""]) as command:
            controls.control("keys", "resume")
        self.assertFalse(controls.preferences()["keys_paused"])
        self.assertEqual(command.call_args.args, ("systemctl", "--user", "start", controls.CONTROLLER_UNIT))

    def test_failed_resume_start_still_restores_paused_preference(self):
        controls.set_preference("keys_paused", True)
        with patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "command", side_effect=[subprocess.CalledProcessError(1, "systemctl"), subprocess.CalledProcessError(1, "systemctl")]):
            with self.assertRaises(subprocess.CalledProcessError):
                controls.control("keys", "resume")
        self.assertTrue(controls.preferences()["keys_paused"])

    def test_refresh_also_loads_a_garbage_collected_controller(self):
        with patch("sys.argv", ["synergy-keys", "refresh"]), patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "command", side_effect=[subprocess.CalledProcessError(1, "systemctl", stderr="Unit not loaded"), ""]) as command, patch.object(cli, "request", return_value={"message": "Reapplying mappings"}), redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main(), 0)
        self.assertEqual(command.call_args.args, ("systemctl", "--user", "start", controls.CONTROLLER_UNIT))

    def test_sharing_pause_uses_native_stop_and_preserves_keys_choice(self):
        controls.set_preference("keys_paused", True)
        with patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "native_action") as action, patch.object(controls, "wait_running") as wait:
            controls.control("synergy", "pause")
        action.assert_called_once_with("Stop")
        wait.assert_called_once_with(False)
        self.assertEqual(controls.preferences(), {"keys_paused": True, "synergy_paused": True})

    def test_stopped_sharing_pause_is_idempotent(self):
        with patch.object(controls.synergy, "processes", return_value={"running": False}), patch.object(controls, "native_action") as action:
            controls.control("synergy", "pause")
        action.assert_not_called()

    def test_sharing_resume_uses_native_start(self):
        with patch.object(controls.synergy, "processes", return_value={"running": False}), patch.object(controls, "native_action") as action, patch.object(controls, "wait_running"):
            controls.control("synergy", "resume")
        action.assert_called_once_with("Start")
        self.assertFalse(controls.preferences()["synergy_paused"])

    def test_failed_sharing_control_restores_pause_choice(self):
        with patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "native_action", side_effect=OSError("menu missing")):
            with self.assertRaises(OSError):
                controls.control("synergy", "pause")
        self.assertFalse(controls.preferences()["synergy_paused"])

    def test_native_menu_matches_identity_and_title(self):
        def bus(*args):
            if args[-1] == "RegisteredStatusNotifierItems":
                return [":other/Item", ":native/Item"]
            if args[-1] == "Id":
                return controls.NATIVE_ID
            if args[-1] == "Title":
                return "other-app" if args[1] == ":other" else controls.NATIVE_TITLE
            return "/Menu"
        with patch.object(controls, "bus", side_effect=bus):
            self.assertEqual(controls.native_menu(), (":native", "/Menu"))

    def test_native_action_selects_label_from_exported_layout(self):
        tree = [0, {}, [{"data": [3, {"label": {"data": "Stop"}}, []]}]]
        with patch.object(controls, "native_menu", return_value=(":native", "/Menu")), patch.object(controls, "bus", return_value=[1, tree]), patch.object(controls, "command") as command:
            controls.native_action("Stop")
        self.assertEqual(command.call_args.args[-5:], ("3", "clicked", "i", "0", "0"))

    def test_resume_after_complete_app_exit_launches_daemon(self):
        with patch.object(controls.synergy, "processes", side_effect=[{"running": False}, {"running": True}]), patch.object(controls, "native_action", side_effect=controls.MenuUnavailable("menu absent")), patch.object(controls, "command") as command, patch.object(controls, "wait_running"):
            controls.control("synergy", "resume")
        self.assertEqual(command.call_args.args[0], "flatpak")
        self.assertEqual(command.call_args.args[-1], "-d")

    def test_malformed_native_protocol_rolls_back_pause_preference(self):
        with patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "native_menu", return_value=(":native", "/Menu")), patch.object(controls, "bus", return_value=[1, []]):
            with self.assertRaisesRegex(OSError, "protocol changed"):
                controls.control("synergy", "pause")
        self.assertFalse(controls.preferences()["synergy_paused"])


if __name__ == "__main__":
    unittest.main()
