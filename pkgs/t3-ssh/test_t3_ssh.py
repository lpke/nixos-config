"""Lifecycle guarantees and transport health, without touching user services."""

from contextlib import contextmanager
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from t3_ssh import runtime


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.environment = patch.dict(os.environ, XDG_RUNTIME_DIR=self.temp.name)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.session = "desktop-login-1"
        self.actions = []

        def systemctl(*args):
            if args[0] == "show":
                return self.session
            self.actions.append(args)
            return ""

        self.controller = patch.object(runtime, "systemctl", side_effect=systemctl)
        self.controller.start()
        self.addCleanup(self.controller.stop)

    def test_first_launch_starts_both_and_later_windows_do_nothing(self):
        runtime.control("auto-start")
        runtime.control("auto-start")
        self.assertEqual(self.actions, [("--no-block", "start", runtime.TARGET, runtime.TUNNEL)])

    def test_pause_is_respected_until_explicit_start(self):
        runtime.control("auto-start")
        runtime.control("stop")
        runtime.control("auto-start")
        self.assertEqual(self.actions[-1], ("stop", runtime.TUNNEL))
        self.assertEqual(len(self.actions), 2)
        runtime.control("start")
        self.assertEqual(self.actions[-1], ("--no-block", "start", runtime.TARGET, runtime.TUNNEL))

    def test_quit_stops_group_and_is_respected_by_later_launches(self):
        runtime.control("quit")
        runtime.control("auto-start")
        self.assertEqual(self.actions, [("stop", runtime.TARGET, runtime.TUNNEL, runtime.TRAY)])

    def test_next_desktop_login_can_start_again_with_lingering_manager(self):
        runtime.control("quit")
        self.session = "desktop-login-2"
        runtime.control("auto-start")
        self.assertEqual(self.actions[-1], ("--no-block", "start", runtime.TARGET, runtime.TUNNEL))

    def test_failed_start_can_be_retried_on_next_launch(self):
        with patch.object(runtime, "systemctl", side_effect=[self.session, subprocess.TimeoutExpired("systemctl", 20)]):
            with self.assertRaises(subprocess.TimeoutExpired):
                runtime.control("auto-start")
        self.assertFalse((runtime.directory() / "launched").exists())
        runtime.control("auto-start")
        self.assertEqual(len(self.actions), 1)


class HealthTests(unittest.TestCase):
    def setUp(self):
        self.config = runtime.Configuration("test-mac", 13773, 3773, "darwin")
        self.config_patch = patch.object(runtime, "configuration", return_value=self.config)
        self.config_patch.start()
        self.addCleanup(self.config_patch.stop)

    @contextmanager
    def connected_service(self):
        with patch.object(runtime, "service_state", return_value={"ActiveState": "active", "SubState": "running"}):
            yield

    def probe(self, payload):
        from io import BytesIO
        response = BytesIO(json.dumps(payload).encode())
        with self.connected_service(), patch("urllib.request.OpenerDirector.open", return_value=response):
            return runtime.snapshot()

    def test_green_requires_t3_descriptor_on_expected_remote_os(self):
        result = self.probe({"environmentId": "test-environment", "label": "Mac", "platform": {"os": "darwin"}})
        self.assertTrue(result["connected"])
        self.assertEqual(result["status"], "Connected")

    def test_another_os_or_non_t3_payload_is_red(self):
        for payload in [{"environmentId": "other", "platform": {"os": "linux"}}, {}, [], {"platform": []}]:
            with self.subTest(payload=payload):
                result = self.probe(payload)
                self.assertFalse(result["connected"])
                self.assertEqual(result["status"], "Connection error")

    def test_unreachable_mac_is_red_without_raising(self):
        with self.connected_service(), patch("urllib.request.OpenerDirector.open", side_effect=TimeoutError("offline")):
            result = runtime.snapshot()
        self.assertFalse(result["connected"])
        self.assertIn("offline", result["detail"])

    def test_paused_service_is_red_without_probing_a_leftover_listener(self):
        with patch.object(runtime, "service_state", return_value={"ActiveState": "inactive"}), \
                patch("urllib.request.OpenerDirector.open") as probe:
            result = runtime.snapshot()
        self.assertFalse(result["active"])
        self.assertEqual(result["status"], "Paused")
        probe.assert_not_called()

    def test_restarting_service_reports_connection_failure_until_ready(self):
        with patch.object(runtime, "service_state", return_value={"ActiveState": "activating", "SubState": "auto-restart"}), \
                patch("urllib.request.OpenerDirector.open", side_effect=ConnectionRefusedError()):
            result = runtime.snapshot()
        self.assertTrue(result["active"])
        self.assertFalse(result["connected"])


if __name__ == "__main__":
    unittest.main()
