"""Shared launch/quit controls cover all helpers without global VPN changes."""
import subprocess
import unittest
from unittest.mock import patch
from t3_tray import cli

class CommandTests(unittest.TestCase):
    def test_show_starts_all_helpers_and_tray(self):
        with patch("sys.argv",["t3-tray","show"]), patch.object(cli.subprocess,"run",return_value=subprocess.CompletedProcess([],0)) as run:
            self.assertEqual(cli.main(),0)
        calls=[call.args[0] for call in run.call_args_list]
        self.assertEqual(calls,[[p,"start"] for p in cli.HELPERS]+[["systemctl","--user","start","t3-tray.service"]])

    def test_quit_stops_every_helper_before_queuing_tray_stop(self):
        with patch("sys.argv",["t3-tray","quit"]), patch.object(cli.subprocess,"run",return_value=subprocess.CompletedProcess([],0)) as run:
            self.assertEqual(cli.main(),0)
        self.assertEqual([c.args[0] for c in run.call_args_list],[["t3-ssh","quit"],["t3-tailscale","quit"],["git-review-launcher","stop"],["systemctl","--user","--no-block","stop","t3-tray.service"]])

    def test_failed_quit_attempts_remaining_helpers_but_keeps_controls_available(self):
        with patch("sys.argv",["t3-tray","quit"]), patch.object(cli.subprocess,"run",side_effect=[OSError("offline"),subprocess.CompletedProcess([],0),subprocess.CompletedProcess([],0)]) as run:
            self.assertEqual(cli.main(),1)
        self.assertEqual(run.call_count,3)

if __name__=="__main__":unittest.main()
