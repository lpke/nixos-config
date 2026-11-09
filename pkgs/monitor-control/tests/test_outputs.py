from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

from monitor_control.outputs import connected_outputs, edid_name


class OutputTests(unittest.TestCase):
    def test_edid_monitor_descriptor(self):
        data = bytearray(128)
        data[:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"
        data[54:72] = b"\x00\x00\x00\xfc\x00AW3926QW\n    "
        self.assertEqual(edid_name(data), "AW3926QW")
        self.assertEqual(edid_name(b"broken"), "")

    def test_nested_outputs_do_not_inherit_host_monitors(self):
        with tempfile.TemporaryDirectory() as directory:
            connector = Path(directory) / "card0-HDMI-A-1"
            connector.mkdir()
            (connector / "status").write_text("connected")
            (connector / "edid").write_bytes(b"")
            screen = SimpleNamespace(name=lambda: "Virtual-1", model=lambda: "Virtual display",
                                     geometry=lambda: SimpleNamespace(width=lambda: 800))
            outputs = connected_outputs(SimpleNamespace(screens=lambda: [screen]), Path(directory))
            self.assertEqual([item.name for item in outputs], ["Virtual-1"])
            self.assertEqual(outputs[0].title, "Virtual display (Virtual-1)")

    def test_connected_disabled_output_survives_missing_edid(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in ("card0-DP-1", "card0-DP-2"):
                connector = Path(directory) / name
                connector.mkdir()
                (connector / "status").write_text("connected")
            screen = SimpleNamespace(name=lambda: "DP-1", model=lambda: "Samsung",
                                     geometry=lambda: SimpleNamespace(width=lambda: 800))
            outputs = connected_outputs(SimpleNamespace(screens=lambda: [screen]), Path(directory))
            self.assertEqual([(item.name, item.active) for item in outputs],
                             [("DP-1", True), ("DP-2", False)])
