import asyncio
from pathlib import Path
import tempfile
import unittest
from unittest.mock import AsyncMock, patch

from synergy_keys.controller import Controller
from synergy_keys.modes import captures_mode_device
from synergy_keys.synergy import ScreenState


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

    def test_rotated_log_does_not_need_server_start_record(self):
        state = ScreenState("pc")
        state.feed(b'switch from "pc" to "mac" at 1,1\n')
        self.assertTrue(state.remote)
        state.feed(b'jump from "mac" to "pc"\n')
        self.assertFalse(state.remote)

    def test_client_events_are_interpreted_locally(self):
        state = ScreenState("pc")
        state.feed(b'started client\nleaving screen\n')
        self.assertTrue(state.remote)
        state.feed(b'entering screen\n')
        self.assertFalse(state.remote)

    def test_mode_switch_waits_for_device_selection_to_finish(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            device = root / "sys/class/input/event15/device"
            device.mkdir(parents=True)
            (device / "name").write_text("ydotoold virtual device\n")
            process = root / "proc/123"
            descriptors = process / "fd"
            descriptors.mkdir(parents=True)
            (process / "comm").write_text("xremap\n")
            (descriptors / "5").symlink_to("/dev/input/event15")
            with patch("synergy_keys.modes.Path", side_effect=lambda path: root / path.lstrip("/")):
                self.assertFalse(captures_mode_device())
                (descriptors / "6").symlink_to("/dev/uinput")
                self.assertTrue(captures_mode_device())
                (descriptors / "5").unlink()
                self.assertFalse(captures_mode_device())


class ControllerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        patcher = patch("synergy_keys.controller.directory", return_value=self.root)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.log = self.root / "synergy.log"
        self.controller = Controller({"synergy_log": str(self.log), "local_screen": "pc"})

    async def watch(self):
        task = asyncio.create_task(self.controller.watch_screen())
        self.addAsyncCleanup(self.cancel, task)
        await asyncio.sleep(.1)

    async def cancel(self, task):
        task.cancel()
        await asyncio.gather(task, return_exceptions=True)

    async def test_mode_only_depends_on_active_screen(self):
        self.assertEqual(self.controller.desired_mode, "local")
        self.controller.remote = True
        self.assertEqual(self.controller.desired_mode, "mac")

    async def test_rotation_and_truncation_keep_the_active_screen(self):
        self.log.write_text('started server\nswitch from "pc" to "mac" at 1,1\n')
        await self.watch()
        self.assertTrue(self.controller.remote)
        self.log.rename(self.root / "synergy.log.old")
        self.log.write_text('heartbeat\n')
        await asyncio.sleep(.15)
        self.assertTrue(self.controller.remote, "rotation must not restore local mappings")
        self.log.write_text('x\n')
        await asyncio.sleep(.15)
        self.assertTrue(self.controller.remote, "truncation must not restore local mappings")
        with self.log.open('a') as log:
            log.write('switch from "mac" to "pc"\n')
        await asyncio.sleep(.1)
        self.assertFalse(self.controller.remote)

    async def test_missing_log_is_reported_and_recovers(self):
        await self.watch()
        self.assertIn("Cannot read", self.controller.state()["error"])
        self.assertFalse(self.controller.remote)
        self.log.write_text('switch from "pc" to "mac"\n')
        await asyncio.sleep(.55)
        self.assertTrue(self.controller.remote)
        self.assertIsNone(self.controller.state()["error"])

    async def test_keyboard_failure_is_reported_and_recovers(self):
        self.controller.changed.set()
        apply = AsyncMock(side_effect=[OSError("device missing"), None])
        with patch("synergy_keys.controller.modes.apply", apply):
            task = asyncio.create_task(self.controller.reconcile())
            self.addAsyncCleanup(self.cancel, task)
            await asyncio.sleep(.05)
            self.assertEqual(self.controller.mode_error, "device missing")
            await asyncio.sleep(.55)
            self.assertEqual(self.controller.applied_mode, "local")
            self.assertIsNone(self.controller.mode_error)


if __name__ == "__main__":
    unittest.main()
