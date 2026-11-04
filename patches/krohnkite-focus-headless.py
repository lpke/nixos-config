#!/usr/bin/env python3
"""Exercise the built Krohnkite callbacks with real apps on private virtual outputs."""

import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def run_session(root):
    processes = []
    with (root / "session.log").open("w") as log:
        try:
            processes.append(subprocess.Popen([
                "kwin_wayland", "--virtual", "--width", "1600", "--height", "1000",
                "--output-count", "2", "--socket", "focus-test",
                "--no-lockscreen", "--no-kactivities",
            ], stdout=log, stderr=log, start_new_session=True))
            deadline = time.monotonic() + 15
            while not (root / "runtime/focus-test").exists():
                if processes[0].poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Virtual KWin failed to start")
                time.sleep(0.1)

            clients_env = os.environ | {
                "WAYLAND_DISPLAY": "focus-test", "QT_QPA_PLATFORM": "wayland",
            }
            commands = [
                ["alacritty", "--config-file", "/dev/null", "--command", "sleep", "120"],
                ["helium", f"--user-data-dir={root / 'browser'}", "--no-first-run",
                 "--no-default-browser-check", "--password-store=basic", "--disable-gpu",
                 "--disable-background-networking", "--ozone-platform=wayland", "about:blank"],
            ]
            for command in commands:
                processes.append(subprocess.Popen(
                    command, env=clients_env, stdout=log, stderr=log, start_new_session=True,
                ))

            deadline = time.monotonic() + 25
            while time.monotonic() < deadline:
                output = (root / "session.log").read_text()
                if "FOCUS_CHECK FAIL" in output:
                    raise RuntimeError("Focus assertion failed")
                if "FOCUS_CHECK DONE" in output:
                    print("\n".join(line for line in output.splitlines() if "FOCUS_CHECK" in line))
                    return
                if any(process.poll() is not None for process in processes):
                    raise RuntimeError("A test application exited early")
                time.sleep(0.1)
            raise RuntimeError("Focus checks timed out")
        except Exception:
            print((root / "session.log").read_text(), file=sys.stderr)
            raise
        finally:
            for process in reversed(processes):
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            for process in reversed(processes):
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                # Chromium helpers can outlive the browser and keep writing its profile.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, help="Built Krohnkite package directory")
    parser.add_argument("--private-session", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.private_session:
        run_session(args.private_session)
        return
    if not args.package:
        parser.error("--package is required")

    with tempfile.TemporaryDirectory(prefix="krohnkite-focus-") as directory:
        root = Path(directory)
        for name in ["config", "data", "cache", "runtime", "state", "config-dirs"]:
            (root / name).mkdir(mode=0o700)
        target = root / "data/kwin/scripts/krohnkite"
        shutil.copytree(args.package / "share/kwin/scripts/krohnkite", target)
        qml = target / "contents/ui/main.qml"
        qml.chmod(0o600)
        source = qml.read_text().replace(
            "    id: scriptRoot", "    id: scriptRoot\n    property var testDriver: null"
        ).replace(
            "        (new K.KWinDriver(api)).main();",
            "        testDriver = new K.KWinDriver(api);\n        testDriver.main();",
        )
        if "testDriver.main();" not in source:
            raise RuntimeError("Krohnkite entrypoint changed; update test instrumentation")
        checks = Path(__file__).with_suffix(".qml").read_text()
        qml.write_text(source[:source.rfind("}")] + checks + "}\n")
        (root / "config/kwinrc").write_text(
            "[Plugins]\nkrohnkiteEnabled=true\n[Script-krohnkite]\n"
            "threeColumnLayoutOrder=1\ncolumnsLayoutOrder=2\ntileLayoutOrder=3\n"
            "monocleLayoutOrder=4\nfloatingLayoutOrder=5\ndirectionalKeyDwm=false\n"
        )
        # No D-Bus service activation or access to the owner's system bus.
        (root / "bus.conf").write_text(
            f'<busconfig><type>session</type><listen>unix:tmpdir={root / "runtime"}</listen>'
            '<auth>EXTERNAL</auth><policy context="default"><allow send_destination="*"/>'
            '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>'
        )
        env = {key: value for key, value in os.environ.items() if key not in {
            "DISPLAY", "WAYLAND_DISPLAY", "SESSION_MANAGER", "DBUS_SESSION_BUS_ADDRESS",
            "QT_QPA_PLATFORM",
        }}
        env.update({
            "XDG_CONFIG_HOME": str(root / "config"), "XDG_DATA_HOME": str(root / "data"),
            "XDG_CACHE_HOME": str(root / "cache"), "XDG_RUNTIME_DIR": str(root / "runtime"),
            "XDG_STATE_HOME": str(root / "state"), "XDG_CONFIG_DIRS": str(root / "config-dirs"),
            "DBUS_SYSTEM_BUS_ADDRESS": f"unix:path={root / 'no-system-bus'}",
            "LIBGL_ALWAYS_SOFTWARE": "1", "QT_QUICK_BACKEND": "software", "KWIN_COMPOSE": "Q",
            "QT_FORCE_STDERR_LOGGING": "1", "QT_LOGGING_TO_CONSOLE": "1",
            "QT_LOGGING_RULES": "kwin_scripting.debug=true;js.debug=true",
        })
        subprocess.run([
            "dbus-run-session", f"--config-file={root / 'bus.conf'}", "--",
            sys.executable, str(Path(__file__).resolve()), "--private-session", str(root),
        ], env=env, check=True)


if __name__ == "__main__":
    main()
