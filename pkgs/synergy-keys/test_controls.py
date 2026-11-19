"""No live D-Bus events, input, Flatpak commands or service changes."""

from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import signal
import subprocess
import sys
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

    def test_command_returns_when_daemon_inherits_output(self):
        pid_file = self.root / "daemon.pid"
        launcher = (
            "import pathlib, subprocess, sys; "
            "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'], "
            "start_new_session=True); "
            f"pathlib.Path({str(pid_file)!r}).write_text(str(child.pid)); "
            "print('started')"
        )
        run = subprocess.run

        def bounded_run(*args, **kwargs):
            # A leaked output pipe should fail quickly, without launching Synergy.
            kwargs["timeout"] = .5
            return run(*args, **kwargs)

        try:
            with patch.object(controls.subprocess, "run", side_effect=bounded_run):
                self.assertEqual(controls.command(sys.executable, "-c", launcher), "started")
            os.kill(int(pid_file.read_text()), 0)  # The daemon is still alive.
        finally:
            if pid_file.exists():
                os.kill(int(pid_file.read_text()), signal.SIGTERM)

    def test_command_failure_preserves_output_and_exit_status(self):
        with self.assertRaises(subprocess.CalledProcessError) as caught:
            controls.command(sys.executable, "-c", "import sys; print('out'); print('error', file=sys.stderr); sys.exit(3)")
        self.assertEqual(caught.exception.returncode, 3)
        self.assertEqual(caught.exception.stdout, "out\n")
        self.assertEqual(caught.exception.stderr, "error\n")

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

    def test_launch_restores_tray_and_sharing_without_changing_keys_pause(self):
        controls.set_preference('keys_paused', True)
        with patch.object(controls.synergy, 'processes', return_value={'running': True}), patch.object(controls, 'command') as command, patch.object(controls, 'wait_running'):
            controls.control('synergy', 'launch')
        command.assert_called_once_with('systemctl', '--user', 'restart', controls.TRAY_UNIT)
        self.assertTrue(controls.preferences()['keys_paused'])
        self.assertFalse(controls.preferences()['synergy_paused'])

    def test_quit_closes_only_synergy_and_its_units_and_preserves_keys_choice(self):
        controls.set_preference('keys_paused', True)
        def result(*args):
            return 'com.symless.synergy\nother.app' if args[:2] == ('flatpak', 'ps') else ''
        with patch.object(controls, 'command', side_effect=result) as command:
            controls.control('synergy', 'quit')
        self.assertEqual(command.call_args_list, [
            call('systemctl', '--user', 'stop', controls.CONTROLLER_UNIT),
            call('flatpak', 'ps', '--columns=application'),
            call('flatpak', 'kill', 'com.symless.synergy'),
            call('systemctl', '--user', '--no-block', 'stop', controls.TRAY_UNIT),
        ])
        self.assertEqual(controls.preferences(), {'keys_paused': True, 'synergy_paused': True})

    def test_native_action_selects_label_from_exported_layout(self):
        tree = [0, {}, [{"data": [3, {"label": {"data": "Stop"}}, []]}]]
        with patch.object(controls, "native_menu", return_value=(":native", "/Menu")), patch.object(controls, "bus", return_value=[1, tree]), patch.object(controls, "command") as command:
            controls.native_action("Stop")
        self.assertEqual(command.call_args.args[-5:], ("3", "clicked", "i", "0", "0"))

    def test_cold_resume_finishes_on_core_readiness_with_the_launcher_still_running(self):
        controls.set_preference('synergy_paused', True)
        absent = {'running': False, 'session': None}
        with patch.object(controls.synergy, 'processes', side_effect=[absent, absent, {'running': True}]), patch.object(controls, 'native_action', side_effect=controls.MenuUnavailable('menu absent')), patch.object(controls, 'command') as command:
            controls.control("synergy", "resume")
        command.assert_called_once_with('systemctl', '--user', 'start', 'synergy-native.service')
        self.assertFalse(controls.preferences()['synergy_paused'])

    def test_starting_backend_can_publish_menu_before_core(self):
        starting = {'running': False, 'session': [123, '1']}
        with patch.object(controls.synergy, 'processes', side_effect=[starting, starting, starting, {'running': True}]), patch.object(controls, 'native_action', side_effect=controls.ActionUnavailable('Start not offered')), patch.object(controls, 'command') as command, patch.object(controls.time, 'sleep'):
            controls.control('synergy', 'resume')
        command.assert_not_called()

    def test_queued_pause_is_only_applied_if_still_requested(self):
        with patch.object(controls.synergy, 'processes', return_value={'running': True}), patch.object(controls, 'native_action') as action, patch.object(controls, 'wait_running'):
            controls.set_preference('synergy_paused', False)
            controls.control('synergy', 'apply-saved-pause')
            action.assert_not_called()
            self.assertFalse(controls.preferences()['synergy_paused'])
            controls.set_preference('synergy_paused', True)
            controls.control('synergy', 'apply-saved-pause')
            action.assert_called_once_with('Stop')

    def test_malformed_native_protocol_rolls_back_pause_preference(self):
        with patch.object(controls.synergy, "processes", return_value={"running": True}), patch.object(controls, "native_menu", return_value=(":native", "/Menu")), patch.object(controls, "bus", return_value=[1, []]):
            with self.assertRaisesRegex(OSError, "protocol changed"):
                controls.control("synergy", "pause")
        self.assertFalse(controls.preferences()["synergy_paused"])


if __name__ == "__main__":
    unittest.main()
