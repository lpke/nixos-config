"""Fake D-Bus only: never contact the desktop."""

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import control


class ControlTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / 'source'
        self.cache = self.root / 'cache'
        self.cache.mkdir()
        for name in ('metadata.json', 'contents/ui/main.qml', 'contents/code/script.js'):
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(name)

    def test_stages_every_import_under_a_fresh_url_and_is_removable(self):
        for path in self.source.rglob('*'):
            path.chmod(0o555 if path.is_dir() else 0o444)
        self.addCleanup(lambda: [path.chmod(0o700) for path in self.source.rglob('*') if path.is_dir()])
        one = control.stage(self.source, self.cache)
        two = control.stage(self.source, self.cache)
        self.assertNotEqual(one, two)
        self.assertEqual((one / 'contents/code/script.js').read_text(), 'contents/code/script.js')
        control.shutil.rmtree(one)
        self.assertTrue(two.is_dir())

    def test_incomplete_bundle_is_rejected_before_dbus(self):
        (self.source / 'contents/code/script.js').unlink()
        with patch.object(control, 'scripting') as scripting:
            with self.assertRaisesRegex(RuntimeError, 'Incomplete'):
                control.replace(None, self.source, self.cache)
        scripting.assert_not_called()
        self.assertEqual(list(self.cache.iterdir()), [])

    def test_stop_is_confirmed_before_replacement_starts(self):
        events = []
        def scripting(bus, method, *args):
            events.append(method)
            return [True] if method == 'unloadScript' else [7] if method == 'loadDeclarativeScript' else []
        with patch.object(control, 'scripting', side_effect=scripting), \
             patch.object(control, 'wait_unloaded', side_effect=lambda bus: events.append('confirmed stopped')):
            control.replace(None, self.source, self.cache)
        self.assertEqual(events, ['unloadScript', 'confirmed stopped', 'loadDeclarativeScript', 'start'])

    def test_failed_stop_does_not_start_a_second_tiler(self):
        with patch.object(control, 'scripting', return_value=[False]) as scripting:
            with self.assertRaisesRegex(RuntimeError, 'refused to stop'):
                control.replace(None, self.source, self.cache)
        self.assertEqual(scripting.call_count, 1)
        self.assertEqual(list(self.cache.iterdir()), [])

    def test_refused_replacement_is_reported(self):
        with patch.object(control, 'scripting', side_effect=[[True], [-1]]), \
             patch.object(control, 'wait_unloaded'):
            with self.assertRaisesRegex(RuntimeError, 'refused the replacement'):
                control.replace(None, self.source, self.cache)

    def test_stop_timeout_does_not_start_replacement(self):
        with patch.object(control, 'scripting', return_value=[True]) as scripting, \
             patch.object(control.time, 'monotonic', side_effect=[0, 6]):
            with self.assertRaisesRegex(RuntimeError, 'did not finish stopping'):
                control.wait_unloaded(None)
        self.assertEqual(scripting.call_args.args[1], 'isScriptLoaded')

    def test_recovery_accepts_an_already_loaded_plugin(self):
        with patch.object(control, 'call', side_effect=[[True], ['pending'], ['restarted'], []]) as call:
            control.recover(None)
        methods = [entry.args[4] for entry in call.call_args_list]
        self.assertEqual(methods, ['isEffectLoaded', 'debug', 'debug', 'unloadEffect'])

    def test_recovery_refuses_a_missing_plugin_before_reset(self):
        with patch.object(control, 'call', side_effect=[[False], [False]]) as call:
            with self.assertRaisesRegex(RuntimeError, 'could not be loaded'):
                control.recover(None)
        self.assertEqual(call.call_count, 2)


class LifecycleTests(unittest.TestCase):
    def test_start_restores_controls_without_a_restart(self):
        with patch.object(control.lifecycle, 'command') as command:
            control.lifecycle.launch()
        command.assert_called_once_with('systemctl', '--user', 'start', 'krohnkite-tray.service')

    def test_quit_queues_unit_stop_to_avoid_killing_its_own_menu_command(self):
        with patch.object(control.lifecycle, 'command') as command:
            control.lifecycle.quit_app()
        command.assert_called_once_with('systemctl', '--user', '--no-block', 'stop', 'krohnkite-tray.service')

    def test_stop_disables_autoload_before_unloading_and_does_not_stop_the_tray(self):
        events = []
        with patch.object(control.lifecycle, 'enable', side_effect=lambda value: events.append(('enabled', value))), \
             patch.object(control, 'kwin_available', return_value=True), \
             patch.object(control, 'scripting', side_effect=lambda _, method, *args: events.append(method) or [True]), \
             patch.object(control, 'wait_unloaded', side_effect=lambda _: events.append('stopped')), \
             patch.object(control, 'call', side_effect=lambda *args: events.append(args[4])), \
             patch.object(control.lifecycle, 'quit_app') as quit_app:
            control.stop_tiler(None)
        self.assertEqual(events, [('enabled', False), 'isScriptLoaded', 'unloadScript', 'stopped', 'reconfigure'])
        quit_app.assert_not_called()

    def test_stop_is_safe_after_kwin_has_exited(self):
        with patch.object(control.lifecycle, 'enable') as enabled, \
             patch.object(control, 'kwin_available', return_value=False), \
             patch.object(control, 'scripting') as scripting:
            control.stop_tiler(None)
        enabled.assert_called_once_with(False)
        scripting.assert_not_called()

    def test_start_is_idempotent_and_enables_runtime_choice(self):
        with patch.object(control, 'kwin_available', return_value=True), \
             patch.object(control.lifecycle, 'enable') as enabled, \
             patch.object(control, 'scripting', return_value=[True]), \
             patch.object(control, 'activate') as activate, \
             patch.object(control, 'call'), patch.object(control, 'acknowledge') as ack:
            control.start_tiler(None, None, Path('/unused'))
        enabled.assert_called_once_with(True)
        activate.assert_not_called()
        ack.assert_called_once_with(None, None)

    def test_status_is_read_only(self):
        with patch.object(control, 'kwin_available', return_value=True), \
             patch.object(control, 'scripting', return_value=[False]), \
             patch.object(control.lifecycle, 'enable') as enabled:
            self.assertEqual(control.status(None), {'running': False, 'status': 'Stopped'})
        enabled.assert_not_called()


if __name__ == '__main__':
    unittest.main()
