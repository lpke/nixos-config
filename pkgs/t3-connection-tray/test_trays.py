"""Run both tray suites with PyQt6 and an isolated, explicit session bus."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


root = Path(__file__).resolve().parents[2]
environment = {
    **os.environ,
    "QT_QPA_PLATFORM": "offscreen",
    "PYTHONPATH": os.pathsep.join(str(root / "pkgs" / name) for name in
                                ("t3-ssh", "t3-tailscale", "t3-connection-tray")),
}
with tempfile.TemporaryDirectory(prefix="t3-tray-tests-") as temporary:
    config = Path(temporary) / "session.conf"
    config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>'
                      '<policy context="default"><allow send_destination="*"/>'
                      '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
    result = subprocess.run([
        "dbus-run-session", "--config-file=" + str(config), "--",
        sys.executable, "-B", "-m", "unittest", "discover", "-s",
        str(root / "pkgs/t3-ssh"), "-p", "test_tray.py", "-v",
    ], env=environment, cwd=root)
    sys.exit(result.returncode)
