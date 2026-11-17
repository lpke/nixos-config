"""Offscreen tray only; native commands are replaced before creating the tray."""

import os
from pathlib import Path
import unittest
from unittest.mock import patch

from PyQt6.QtWidgets import QApplication

from tray import Tray
from tray_icon import svg_icon


@unittest.skipUnless(os.environ.get('QT_QPA_PLATFORM') == 'offscreen', 'requires isolated Qt')
class TrayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.poll = patch.object(Tray, 'poll')
        self.poll.start()
        self.addCleanup(self.poll.stop)
        self.tray = Tray(self.app)
        self.addCleanup(self.tray.shutdown)

    def test_menu_reports_status_and_keeps_help_and_quit_available(self):
        for running, title in [(True, 'Running'), (False, 'Stopped')]:
            self.tray.state = {'running': running, 'status': title}
            self.tray.display()
            self.assertEqual(self.tray.summary.text(), f'Krohnkite: {title}')
            self.assertFalse(self.tray.summary.isEnabled())
            self.assertEqual(self.tray.actions['start'].isEnabled(), not running)
            for name in ('stop', 'reload', 'restart', 'recover'):
                self.assertEqual(self.tray.actions[name].isEnabled(), running)
            self.assertTrue(self.tray.quit_action.isEnabled())
        self.assertEqual([a.text() for a in self.tray.menu.actions() if a.text()],
                         ['Krohnkite: Stopped', 'Start', 'Stop', 'Reload settings', 'Restart',
                          'Recover KWin scripts', 'Help', 'Quit Krohnkite'])

    def test_menu_dispatches_cli_actions_without_stopping_the_tray_on_stop(self):
        with patch.object(self.tray, 'run') as run:
            self.tray.command('stop')
        run.assert_called_once_with(['stop'], polling=False, action='stop')
        self.assertFalse(self.tray.closing)
        self.assertEqual(self.tray.summary.text(), 'Krohnkite: Stopping')

    def test_only_one_mutation_can_be_pending(self):
        with patch.object(self.tray, 'run') as run:
            self.tray.command('start')
            self.tray.command('quit')
        self.assertEqual(run.call_count, 1)
        self.assertEqual(self.tray.pending, 'start')

    def test_help_window_has_no_command_timeout(self):
        with patch('tray.QProcess'), patch('tray.QTimer') as timer:
            self.tray.command('help')
        timer.return_value.start.assert_not_called()
        self.assertIsNone(self.tray.pending)

    def test_icon_colours_follow_state_and_errors_take_priority(self):
        for running, status, error, color in [
            (True, 'Running', '', '#ffffff'),
            (False, 'Stopped', '', '#808080'),
            (False, 'Unavailable', '', '#da4453'),
            (True, 'Running', 'Command failed', '#da4453'),
            (False, 'Stopped', 'Command failed', '#da4453'),
        ]:
            self.tray.state = {'running': running, 'status': status}
            self.tray.error = error
            self.tray.display()
            self.assertEqual(self.tray.tray.icon().cacheKey(), self.tray.icons[color].cacheKey())

    def test_status_recovery_clears_poll_errors_without_hiding_command_errors(self):
        def finish(action, code, output=b'', error=b''):
            with patch('tray.QProcess') as process, patch('tray.QTimer'):
                process.return_value.readAllStandardError.return_value = error
                process.return_value.readAllStandardOutput.return_value = output
                self.tray.run([action], polling=action == 'status', action=action)
                process.return_value.finished.connect.call_args[0][0](code)

        stopped = b'{"running": false, "status": "Stopped"}'
        with patch.object(self.tray.tray, 'showMessage'):
            finish('status', 1, error=b'Bus unavailable')
            self.assertEqual(self.tray.displayed_icon, '#da4453')
            finish('status', 0, stopped)
            self.assertEqual(self.tray.displayed_icon, '#808080')
            finish('help', 1, error=b'Terminal failed')
            finish('status', 0, stopped)
            self.assertEqual(self.tray.displayed_icon, '#da4453')
            self.assertIn('Terminal failed', self.tray.tray.toolTip())
            finish('stop', 0)
            self.assertEqual(self.tray.displayed_icon, '#808080')

    def test_white_icon_uses_shared_renderer_at_fractional_pixel_sizes(self):
        icon = svg_icon(Path(__file__).with_name('tiling.svg'))
        for size in (16, 20, 22, 24, 25, 30, 32, 36):
            pixmap = icon.pixmap(size, size)
            self.assertEqual(pixmap.width(), size)
            pixels = pixmap.toImage()
            opaque = [pixels.pixelColor(x, y) for x in range(size) for y in range(size)
                      if pixels.pixelColor(x, y).alpha() > 200]
            self.assertTrue(opaque)
            self.assertTrue(all((p.red(), p.green(), p.blue()) == (255, 255, 255) for p in opaque))


if __name__ == '__main__':
    unittest.main()
