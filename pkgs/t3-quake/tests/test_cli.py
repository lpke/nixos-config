import sys
import unittest
from unittest.mock import patch

from t3_quake import cli


class RestartTests(unittest.TestCase):
    def test_only_a_quake_lease_starts_the_helper_when_reloading_assets(self):
        for mode, expected in [(None, 'stop'), ('quake', 'restart')]:
            with self.subTest(mode=mode), \
                    patch.object(sys, 'argv', ['t3-quake', 'restart']), \
                    patch.object(cli, 'QCoreApplication'), \
                    patch.object(cli, 'running_mode', return_value=mode), \
                    patch.object(cli, 'call', return_value=[True]) as remote, \
                    patch.object(cli.subprocess, 'run') as systemctl, \
                    patch.object(cli.QDBusConnection, 'sessionBus'):
                cli.main()
                systemctl.assert_called_once_with(
                    ['systemctl', '--user', expected, 't3-quake.service'], check=True, timeout=8)
                self.assertTrue(any(c.args[3] == 'loadDeclarativeScript' for c in remote.call_args_list))


if __name__ == '__main__':
    unittest.main()
