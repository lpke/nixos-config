"""Tray visibility never changes either transport."""

import unittest
from unittest.mock import patch

from t3_tray import cli


class CommandTests(unittest.TestCase):
    def test_visibility_commands_only_control_shared_tray_unit(self):
        for action, verb in [("show", "start"), ("quit", "stop")]:
            with self.subTest(action=action), patch("sys.argv", ["t3-tray", action]), \
                    patch.object(cli.subprocess, "run") as run:
                run.return_value.returncode = 0
                self.assertEqual(cli.main(), 0)
                run.assert_called_once_with(["systemctl", "--user", verb, "t3-tray.service"])


if __name__ == "__main__":
    unittest.main()
