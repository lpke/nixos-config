"""Scoped route controls and gateway health without changing live preferences."""

from io import BytesIO
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from t3_tailscale import runtime


CONFIG = runtime.Configuration("192.0.2.4/32", "http://192.0.2.4:3773", "11111111-1111-4111-8111-111111111111")


class ControlTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.enterContext(patch.dict(os.environ, XDG_RUNTIME_DIR=temporary.name))
        self.enterContext(patch.object(runtime, "configuration", return_value=CONFIG))
        self.prefs = {"AdvertiseRoutes": ["198.51.100.0/24"], "NoSNAT": False}
        self.enterContext(patch.object(runtime, "tailscale_json", side_effect=lambda *a:
                                     self.prefs if a == ("debug", "prefs") else {"BackendState": "Running"}))
        self.commands = self.enterContext(patch.object(runtime, "command"))

    def test_start_preserves_other_routes_and_only_starts_own_tray(self):
        runtime.control("start")
        self.assertEqual(self.commands.call_args_list[0].args,
                         ("tailscale", "set", "--advertise-routes=198.51.100.0/24,192.0.2.4/32"))
        self.assertEqual(self.commands.call_args_list[1].args,
                         ("systemctl", "--user", "start", runtime.TRAY))

    def test_pause_preserves_unrelated_routes_and_does_not_stop_daemon_or_tray(self):
        self.prefs["AdvertiseRoutes"].append(CONFIG.route)
        runtime.control("stop")
        self.commands.assert_called_once_with("tailscale", "set", "--advertise-routes=198.51.100.0/24")

    def test_quit_withdraws_before_stopping_own_tray(self):
        self.prefs["AdvertiseRoutes"] = [CONFIG.route]
        runtime.control("quit")
        self.assertEqual([call.args for call in self.commands.call_args_list], [
            ("tailscale", "set", "--advertise-routes="),
            ("systemctl", "--user", "stop", runtime.TRAY),
        ])

    def test_repeated_start_does_not_rewrite_preferences(self):
        self.prefs["AdvertiseRoutes"].append(CONFIG.route)
        runtime.control("start")
        self.commands.assert_called_once_with("systemctl", "--user", "start", runtime.TRAY)

    def test_unrelated_shared_nat_preference_is_not_overwritten(self):
        self.prefs["NoSNAT"] = True
        with self.assertRaisesRegex(ValueError, "Source NAT"):
            runtime.control("start")
        self.commands.assert_not_called()

    def test_a_failed_route_update_does_not_claim_start_or_stop_tray(self):
        self.commands.side_effect = PermissionError("operator permission missing")
        with self.assertRaises(PermissionError):
            runtime.control("start")
        self.assertEqual(self.commands.call_count, 1)


class HealthTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch.object(runtime, "configuration", return_value=CONFIG))
        self.prefs = {"AdvertiseRoutes": [CONFIG.route], "NoSNAT": False}
        self.state = {"BackendState": "Running", "Self": {"PrimaryRoutes": [CONFIG.route]}}
        self.enterContext(patch.object(runtime, "tailscale_json", side_effect=lambda *a:
                                     self.prefs if a == ("debug", "prefs") else self.state))
        self.forward = self.enterContext(patch.object(runtime, "forwarding_enabled", return_value=True))
        self.probe = self.enterContext(patch("urllib.request.OpenerDirector.open"))
        self.probe.return_value = BytesIO(json.dumps({"environmentId": CONFIG.environment_id}).encode())

    def test_green_requires_configured_environment(self):
        self.assertTrue(runtime.snapshot()["connected"])

    def test_wrong_identity_is_red(self):
        self.probe.return_value = BytesIO(b'{"environmentId":"another-machine"}')
        self.assertEqual(runtime.snapshot()["status"], "Mac unavailable")

    def test_paused_route_does_not_probe_direct_lan_and_show_false_green(self):
        self.prefs["AdvertiseRoutes"] = []
        self.assertEqual(runtime.snapshot()["status"], "Paused")
        self.probe.assert_not_called()

    def test_unapproved_route_is_red_even_when_lan_works(self):
        self.state["Self"]["PrimaryRoutes"] = []
        self.assertEqual(runtime.snapshot()["status"], "Approval needed")
        self.probe.assert_not_called()

    def test_disconnected_tailscale_does_not_probe_mac(self):
        self.state["BackendState"] = "NeedsLogin"
        self.assertEqual(runtime.snapshot()["status"], "Tailscale disconnected")
        self.probe.assert_not_called()

    def test_forwarding_or_nat_failure_is_red(self):
        self.forward.return_value = False
        self.assertFalse(runtime.snapshot()["connected"])
        self.forward.return_value = True
        self.prefs["NoSNAT"] = True
        self.assertFalse(runtime.snapshot()["connected"])
        self.probe.assert_not_called()

    def test_unreachable_mac_is_red(self):
        self.probe.side_effect = TimeoutError("offline")
        self.assertEqual(runtime.snapshot()["status"], "Mac unavailable")


class ConfigurationTests(unittest.TestCase):
    def test_rejects_broad_route_or_embedded_credentials(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, XDG_CONFIG_HOME=temporary):
            path = Path(temporary) / "tailscale-config/t3-gateway.json"
            path.parent.mkdir()
            for route, url in [("192.0.2.0/24", CONFIG.url),
                               (CONFIG.route, "http://user:secret@192.0.2.4:3773"),
                               (CONFIG.route, "http://192.0.2.5:3773")]:
                with self.subTest(route=route, url=url):
                    path.write_text(json.dumps({"route": route, "url": url, "environment_id": CONFIG.environment_id}))
                    with self.assertRaises(ValueError):
                        runtime.configuration()


if __name__ == "__main__":
    unittest.main()
