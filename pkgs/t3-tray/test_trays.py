"""Run Qt tests under an isolated D-Bus session, without touching live units."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen",
                   "PYTHONPATH": os.pathsep.join(str(root / "pkgs" / path)
                                                 for path in ("t3-tray", "tray-support"))}
    with tempfile.TemporaryDirectory(prefix="t3-tray-tests-") as temporary:
        environment["XDG_CACHE_HOME"] = temporary
        config = Path(temporary) / "session.conf"
        config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>'
                          '<policy context="default"><allow send_destination="*"/>'
                          '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
        result = subprocess.run([
            "dbus-run-session", "--config-file=" + str(config), "--", sys.executable,
            "-B", "-m", "unittest", "discover", "-s", str(root / "pkgs/t3-tray"),
            "-p", "test_*.py", "-v",
        ], env=environment, cwd=root)
        sys.exit(result.returncode)
