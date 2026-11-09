from pathlib import Path
import tempfile
import unittest

from PyQt6.QtWidgets import QApplication

from monitor_control.state import ALL, Output, State
from monitor_control.tray import MENU_RIGHT_GUTTER, Tray

app = QApplication.instance() or QApplication([])


class TrayTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.state = State(Path(self.directory.name) / "settings.json")
        self.state.refresh([Output("DP-1", "Samsung (DP-1)"),
                            Output("HDMI-1", "Alienware (HDMI-1)")])
        self.calls = []

        def dispatch(command, target=None):
            self.calls.append((command, target))
            if command == "toggle":
                self.state.toggle(target)
            elif command == "select":
                self.state.select(target)
            if hasattr(self, "tray"):
                self.tray.sync()

        self.tray = Tray(self.state, dispatch)
        self.addCleanup(self.tray.icon.hide)

    def test_exact_menu_names_and_shared_monitor_names(self):
        self.assertEqual([item.text() for item in self.tray.menu.actions()],
                         ["Black out" + MENU_RIGHT_GUTTER,
                          "Black out hotkey monitor" + MENU_RIGHT_GUTTER, "Label monitors", "Quit"])
        for menu in (self.tray.blackout, self.tray.hotkey):
            self.assertEqual([item.text() for item in menu.actions()],
                             ["All monitors", "Samsung (DP-1)", "Alienware (HDMI-1)"])
        self.assertTrue(self.tray.target_actions[ALL].isChecked())

    def test_action_checks_follow_partial_all_and_external_state(self):
        self.tray.black_actions["DP-1"].trigger()
        self.assertTrue(self.tray.black_actions["DP-1"].isChecked())
        self.assertFalse(self.tray.black_actions[ALL].isChecked())
        self.tray.black_actions[ALL].trigger()
        self.assertTrue(all(item.isChecked() for item in self.tray.black_actions.values()))
        self.tray.black_actions[ALL].trigger()
        self.assertFalse(any(item.isChecked() for item in self.tray.black_actions.values()))
        self.state.toggle("HDMI-1")
        self.tray.sync()
        self.assertTrue(self.tray.black_actions["HDMI-1"].isChecked())

    def test_hotkey_selection_is_exclusive(self):
        self.tray.target_actions["HDMI-1"].trigger()
        self.assertEqual(self.state.target, "HDMI-1")
        self.assertFalse(self.tray.target_actions[ALL].isChecked())
        self.assertTrue(self.tray.target_actions["HDMI-1"].isChecked())
