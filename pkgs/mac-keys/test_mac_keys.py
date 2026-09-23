import asyncio
from pathlib import Path
import tempfile
import unittest
from unittest.mock import AsyncMock, patch

from mac_keys.controller import AttemptState, Controller
from mac_keys.modes import selected_mode
from mac_keys.observer import Observer
from mac_keys.synergy import ScreenState


class AttemptTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / "attempt.json"

    def test_first_attempt_only_and_manual_retry_after_restart(self):
        state = AttemptState(self.path, [12, "100"])
        self.assertTrue(state.claim())
        restarted = AttemptState(self.path, [12, "100"])
        self.assertFalse(restarted.claim())
        self.assertTrue(restarted.claim(manual=True))
        self.assertFalse(AttemptState(self.path, [12, "100"]).claim())

    def test_stop_survives_restart_until_explicit_start(self):
        state = AttemptState(self.path, [12, "100"])
        state.pause()
        restarted = AttemptState(self.path, [12, "100"])
        self.assertFalse(restarted.claim())
        self.assertTrue(restarted.claim(manual=True))
        self.assertFalse(restarted.value["paused"])

    def test_new_synergy_session_allows_one_attempt(self):
        AttemptState(self.path, [12, "100"]).claim()
        self.assertTrue(AttemptState(self.path, [12, "200"]).claim())


class ModeTests(unittest.TestCase):
    terminals = ["org.alacritty", "com.googlecode.iterm2"]

    def test_local_ignores_remote_focus(self):
        for app in [None, *self.terminals, "com.apple.finder"]:
            self.assertEqual(selected_mode(False, app, self.terminals), "local")

    def test_terminals_and_unknown_preserve_control(self):
        for app in [None, *self.terminals]:
            self.assertEqual(selected_mode(True, app, self.terminals), "synergy-terminal")
        self.assertEqual(selected_mode(True, "com.apple.finder", self.terminals), "mac")

    def test_app_list_is_configurable(self):
        self.assertEqual(selected_mode(True, "custom.terminal", ["custom.terminal"]), "synergy-terminal")


class ScreenTests(unittest.TestCase):
    def test_partial_switch_records_and_shutdown(self):
        state = ScreenState("pc")
        state.feed(b'started server\nswitch from "pc"')
        self.assertFalse(state.remote)
        state.feed(b' to "mac" at 1,1\n')
        self.assertTrue(state.remote)
        state.feed(b'jump from "mac" to "pc"\n')
        self.assertFalse(state.remote)
        state.feed(b'switch from "pc" to "mac"\nstopped server\n')
        self.assertFalse(state.remote)


class ObserverTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.updates = []
        self.observer = Observer({"ssh_socket": "/tmp/test-control", "host": "test"},
                                 lambda *args: self.updates.append(args))

    async def test_failed_ssh_does_not_retry(self):
        command = AsyncMock(side_effect=[(1, b"", b""), (1, b"", b"Connection refused")])
        with patch("mac_keys.observer.run_command", command):
            await self.observer.run()
        self.assertEqual(command.await_count, 2)
        self.assertEqual(self.updates[-1], ("Waiting for Mac SSH", None, "Connection refused"))

    async def test_cached_master_needs_no_service_start(self):
        command = AsyncMock(return_value=(0, b"", b""))
        with patch("mac_keys.observer.run_command", command):
            await self.observer.connect()
        self.assertEqual(command.await_count, 1)
        self.assertIn("check", command.call_args.args)

    async def test_failed_master_after_start_does_not_restart(self):
        command = AsyncMock(side_effect=[(1, b"", b""), (0, b"", b""),
                                        (1, b"", b""), (3, b"", b"")])
        with patch("mac_keys.observer.run_command", command):
            await self.observer.run()
        self.assertEqual(command.await_count, 4)
        self.assertEqual(self.updates[-1][0], "Waiting for Mac SSH")

    def test_observer_cannot_open_an_uncached_connection(self):
        self.assertIn("ProxyCommand=false", self.observer.ssh())


class ControllerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        patcher = patch("mac_keys.controller.directory", return_value=self.root)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.controller = Controller({"terminal_applications": ModeTests.terminals},
                                     {"session": [12, "100"]})

    async def test_stop_cancels_observer_and_clears_stale_gui_focus(self):
        task = asyncio.create_task(asyncio.sleep(60))
        self.controller.observer_task = task
        self.controller.remote = True
        self.controller.update("Connected", "com.apple.finder", None)
        self.assertEqual(self.controller.desired_mode, "mac")
        await self.controller.stop_detection()
        self.assertTrue(task.cancelled())
        self.assertEqual(self.controller.desired_mode, "synergy-terminal")
        self.assertEqual(self.controller.status, "Detection stopped")

    async def test_ssh_failure_clears_gui_focus_but_not_screen_state(self):
        self.controller.remote = True
        self.controller.update("Connected", "com.apple.finder", None)
        self.controller.update("Waiting for Mac SSH", None, "Disconnected")
        self.assertEqual(self.controller.desired_mode, "synergy-terminal")
        self.assertEqual(self.controller.state()["screen"], "Mac")

    async def test_keyboard_failure_is_reported_and_recovers(self):
        self.controller.changed.set()
        apply = AsyncMock(side_effect=[OSError("device missing"), None])
        with patch("mac_keys.controller.modes.apply", apply):
            task = asyncio.create_task(self.controller.reconcile())
            await asyncio.sleep(0.05)
            self.assertEqual(self.controller.mode_error, "device missing")
            await asyncio.sleep(0.55)
            self.assertEqual(self.controller.applied_mode, "local")
            self.assertIsNone(self.controller.mode_error)
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)


if __name__ == "__main__":
    unittest.main()
