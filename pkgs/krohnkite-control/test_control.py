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


if __name__ == '__main__':
    unittest.main()
