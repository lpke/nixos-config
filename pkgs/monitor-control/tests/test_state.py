from pathlib import Path
import tempfile
import unittest

from monitor_control.state import ALL, Output, State


class StateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "settings.json"
        self.state = State(self.path)
        self.outputs = [Output("DP-1", "Samsung (DP-1)"),
                        Output("HDMI-1", "Alienware (HDMI-1)"),
                        Output("DP-2", "Acer (DP-2)", False)]
        self.state.refresh(self.outputs)

    def test_all_fills_partial_then_clears_all(self):
        self.assertEqual(self.state.target, ALL)
        self.state.toggle("DP-1")
        self.assertFalse(self.state.all_black)
        self.state.toggle(ALL)
        self.assertEqual(self.state.blacked, {"DP-1", "HDMI-1"})
        self.assertTrue(self.state.all_black)
        self.state.toggle(ALL)
        self.assertEqual(self.state.blacked, set())
        self.state.toggle(ALL)
        self.assertTrue(self.state.all_black)

    def test_independent_covers_and_disabled_output(self):
        self.state.toggle("DP-1")
        self.state.toggle("HDMI-1")
        self.state.toggle("DP-1")
        self.assertEqual(self.state.blacked, {"HDMI-1"})
        with self.assertRaisesRegex(ValueError, "unavailable"):
            self.state.toggle("DP-2")
        self.assertEqual(self.state.blacked, {"HDMI-1"})

    def test_persist_target_without_persisting_covers(self):
        self.state.select("HDMI-1")
        self.state.toggle("HDMI-1")
        loaded = State(self.path)
        self.assertEqual(loaded.target, "HDMI-1")
        self.assertEqual(loaded.blacked, set())

    def test_disconnected_target_never_retargets(self):
        self.state.select("HDMI-1")
        self.state.toggle(ALL)
        self.state.refresh(self.outputs[:1])
        self.assertEqual(self.state.blacked, {"DP-1"})
        with self.assertRaises(ValueError):
            self.state.toggle(self.state.target)
        self.assertEqual(self.state.target, "HDMI-1")
        self.state.refresh([])
        self.assertFalse(self.state.all_black)

    def test_corrupt_settings_and_failed_save(self):
        self.path.write_text("{broken")
        self.assertEqual(State(self.path).target, ALL)
        self.state.settings = self.path / "child"
        with self.assertRaises(OSError):
            self.state.select("DP-1")
        self.assertEqual(self.state.target, ALL)
