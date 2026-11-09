from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import socket
import tempfile
import time
import unittest

from PyQt6.QtWidgets import QApplication

from monitor_control.ipc import Server

app = QApplication.instance() or QApplication([])


class IpcTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "controller.sock"
        self.calls = []
        def dispatch(command, target):
            self.calls.append((command, target))
            return {"ok": True, "sequence": len(self.calls)}
        self.server = Server(self.path, dispatch)
        self.addCleanup(self.server.close)

    def transact(self, chunks):
        def client():
            with socket.socket(socket.AF_UNIX) as connection:
                connection.settimeout(3)
                connection.connect(str(self.path))
                for chunk in chunks:
                    connection.sendall(chunk)
                    time.sleep(.01)
                data = b""
                while b"\n" not in data:
                    chunk = connection.recv(65536)
                    if not chunk:
                        break
                    data += chunk
                return data
        with ThreadPoolExecutor(max_workers=1) as pool:
            result = pool.submit(client)
            deadline = time.monotonic() + 4
            while not result.done() and time.monotonic() < deadline:
                app.processEvents()
                time.sleep(.005)
            return result.result(timeout=.2)

    def test_fragmented_frame_gets_one_reply(self):
        result = json.loads(self.transact([b'{"command":"toggle",', b'"target":"DP-1"}\n']))
        self.assertTrue(result["ok"])
        self.assertEqual(self.calls, [("toggle", "DP-1")])

    def test_invalid_message_and_target_do_not_dispatch(self):
        for data in (b'[]\n', b'{"command":"toggle","target":{}}\n', b'not-json\n'):
            self.assertFalse(json.loads(self.transact([data]))["ok"])
        self.assertEqual(self.calls, [])

    def test_oversized_frame_is_closed_without_dispatch(self):
        self.assertEqual(self.transact([b'x' * 17000 + b'\n']), b'')
        self.assertEqual(self.calls, [])
