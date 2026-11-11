import json
import unittest
from unittest.mock import patch

from PyQt6.QtWidgets import QApplication
from t3_quake.daemon import Bridge, Placeholder

app = QApplication.instance() or QApplication([])


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge = Bridge(app)

    def tearDown(self):
        self.bridge.timer.stop()

    def exchange(self):
        return json.loads(self.bridge.Exchange(json.dumps({'id': 't3', 'mode': 'normal'})))

    def test_rapid_double_toggle_cancels_before_delivery(self):
        self.bridge.Command('toggle')
        self.bridge.Command('toggle')
        self.assertIsNone(self.exchange()['action'])

    def test_toggle_is_delivered_once(self):
        self.bridge.Command('toggle')
        self.assertEqual(self.exchange()['action'], 'toggle')
        self.assertIsNone(self.exchange()['action'])

    def test_restart_identity_changes(self):
        other = Bridge(app)
        try:
            self.assertNotEqual(self.exchange()['instance'], other.instance)
        finally:
            other.timer.stop()

    def test_invalid_protocol_returns_error_without_crashing(self):
        for message in ('null', '{}', 'bad json', '{"id":"t3","mode":"invalid"}'):
            self.assertIn('error', json.loads(self.bridge.Exchange(message)))

    def test_read_only_status_does_not_queue_actions(self):
        self.bridge.Command('status')
        self.assertEqual(self.bridge.sequence, 0)
        self.assertIsNone(self.exchange()['action'])

    def test_watchdog_stops_orphaned_helper(self):
        self.exchange()
        with patch('t3_quake.daemon.time.monotonic', return_value=self.bridge.seen + 4), \
                patch('t3_quake.daemon.running_mode', return_value=None), \
                patch.object(self.bridge.app, 'quit') as quit_app:
            self.bridge.watchdog()
            quit_app.assert_called_once()

    def test_launcher_lease_keeps_helper_alive_during_an_updater_window_gap(self):
        self.exchange()
        with patch('t3_quake.daemon.time.monotonic', return_value=self.bridge.seen + 4), \
                patch('t3_quake.daemon.running_mode', return_value='quake'), \
                patch.object(self.bridge.app, 'quit') as quit_app:
            self.bridge.watchdog()
            quit_app.assert_not_called()

    def test_fractional_monitor_geometry_is_rounded_for_qt_widgets(self):
        widget = Placeholder('t3', {'width': 960.8, 'height': 762.4})
        self.assertEqual((widget.width(), widget.height()), (961, 762))
        widget.close()


if __name__ == '__main__':
    unittest.main()
