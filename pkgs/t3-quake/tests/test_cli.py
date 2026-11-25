import json
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


class ToggleTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch.object(sys, 'argv', ['t3-quake', 'toggle']))
        self.enterContext(patch.object(cli, 'QCoreApplication'))
        self.mode = self.enterContext(patch.object(cli, 'running_mode', return_value='quake'))
        bus = self.enterContext(patch.object(cli.QDBusConnection, 'sessionBus'))
        bus.return_value.interface.return_value.isServiceRegistered.return_value.value.return_value = True
        self.remote = self.enterContext(patch.object(cli, 'call'))
        self.reload = self.enterContext(patch.object(cli, 'reload_controller'))
        self.notify = self.enterContext(patch.object(cli, 'notify'))

    def replies(self, *heartbeat_ages):
        self.remote.side_effect = [[json.dumps({'connected': True, 'heartbeat_age': age})]
                                   for age in heartbeat_ages]

    def commands(self):
        return [c.args[-1] for c in self.remote.call_args_list]

    def test_recent_heartbeat_toggles_without_reloading(self):
        self.replies(0.1, 0.1)
        cli.main()
        self.reload.assert_not_called()
        self.assertEqual(self.commands(), ['status', 'toggle'])

    def test_stale_heartbeat_reloads_then_toggles(self):
        self.replies(60, 0.1, 0.1)
        self.reload.side_effect = lambda mode: self.assertEqual(self.commands(), ['status'])
        cli.main()
        self.reload.assert_called_once_with('quake')
        self.assertEqual(self.commands(), ['status', 'status', 'toggle'])

    def test_stale_heartbeat_after_reload_stops_before_toggle(self):
        self.replies(60, 4)
        with self.assertRaises(SystemExit) as failure:
            cli.main()
        self.assertEqual(failure.exception.code, 1)
        self.reload.assert_called_once_with('quake')
        self.assertEqual(self.commands(), ['status', 'status'])
        self.notify.assert_called_once()

    def test_ended_session_leaves_the_controller_alone(self):
        self.mode.side_effect = ['quake', None]
        self.replies(60)
        with self.assertRaises(SystemExit):
            cli.main()
        self.reload.assert_not_called()
        self.assertEqual(self.commands(), ['status'])


if __name__ == '__main__':
    unittest.main()
