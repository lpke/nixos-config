#!/usr/bin/env python3
"""Exercise the built Krohnkite callbacks with real apps on private virtual outputs."""

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def check_focus_lifecycle(root):
    """Dispatch registered shortcuts, unload Krohnkite, and load it again."""
    address = os.environ["DBUS_SESSION_BUS_ADDRESS"]
    if str(root / "runtime") not in address:
        raise RuntimeError("Lifecycle checks require the private test bus")

    def bus(path, interface, method, *args, service="org.kde.KWin"):
        result = subprocess.run([
            "busctl", f"--address={address}", "--timeout=5s", "--json=short",
            "call", service, path, interface, method, *args,
        ], capture_output=True, text=True, check=True)
        return json.loads(result.stdout)["data"] if result.stdout.strip() else []

    def scripting(method, *args):
        return bus("/Scripting", "org.kde.kwin.Scripting", method, *args)

    def wait_for(predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        raise RuntimeError("Lifecycle check timed out")

    count = 0
    def script(code, condition="true"):
        nonlocal count
        count += 1
        marker = f"ROUTER_CHECK {count}"
        file = root / f"lifecycle-{count}.js"
        file.write_text(
            'var apps = workspace.stackingOrder.filter(w => w.normalWindow && '
            '["Alacritty", "helium"].indexOf(String(w.resourceClass)) >= 0);\n'
            + code + f'\nprint("{marker}", ({condition}) ? "PASS" : "FAIL");\n'
        )
        scripting("loadScript", "ss", str(file), f"lifecycle-{count}")
        # Start the script objects directly. KWin can reuse D-Bus object IDs
        # after unload, so a returned ID need not identify the new object path.
        scripting("start")
        wait_for(lambda: marker in (root / "session.log").read_text())
        output = (root / "session.log").read_text()
        if marker + " FAIL" in output:
            raise RuntimeError(f"Lifecycle assertion failed: {condition}")
        scripting("unloadScript", "s", f"lifecycle-{count}")

    def invoke(direction):
        bus("/component/kwin", "org.kde.kglobalaccel.Component", "invokeShortcut",
            "s", "DirectionalFocus" + direction, service="org.kde.kglobalaccel")
        time.sleep(0.2)

    def unload():
        config = root / "config/kwinrc"
        config.write_text(config.read_text().replace("krohnkiteEnabled=true", "krohnkiteEnabled=false"))
        scripting("start")
        wait_for(lambda: not scripting("isScriptLoaded", "s", "krohnkite")[0])
        assert scripting("isScriptLoaded", "s", "directional-focus")[0]

    def load():
        config = root / "config/kwinrc"
        config.write_text(config.read_text()
                          .replace("krohnkiteEnabled=false", "krohnkiteEnabled=true")
                          .replace("runFocusTests=true", "runFocusTests=false"))
        scripting("start")
        time.sleep(0.5)
        assert scripting("isScriptLoaded", "s", "krohnkite")[0]

    def native_direction(direction):
        x, y = {"Left": (100, 500), "Right": (900, 500),
                "Up": (500, 100), "Down": (500, 600)}[direction]
        script(
            'apps.forEach(w => workspace.sendClientToScreen(w, workspace.screens[0]));'
            'var a = apps.find(w => String(w.resourceClass) === "Alacritty");'
            'var b = apps.find(w => String(w.resourceClass) === "helium");'
            'a.frameGeometry = {x:500,y:500,width:300,height:200};'
            f'b.frameGeometry = {{x:{x},y:{y},width:300,height:200}};'
            'workspace.activeWindow = a;'
        )
        time.sleep(0.2)
        invoke(direction)
        script("", 'String(workspace.activeWindow.resourceClass) === "helium"')
        print(f"ROUTER_CHECK PASS native {direction} with Krohnkite unloaded")

    def tiled_direction(direction):
        script(
            'apps.forEach(w => workspace.sendClientToScreen(w, workspace.screens[0]));'
        )
        time.sleep(0.4)
        source_index = 0 if direction == "Right" else 1
        script('apps.sort((a,b) => a.frameGeometry.x - b.frameGeometry.x);'
               f'workspace.activeWindow = apps[{source_index}];')
        invoke(direction)
        script('apps.sort((a,b) => a.frameGeometry.x - b.frameGeometry.x);',
               f'workspace.activeWindow === apps[{1 - source_index}]')
        print(f"ROUTER_CHECK PASS tiled {direction} with Krohnkite loaded")

    unload()
    for direction in ["Left", "Right", "Up", "Down"]:
        native_direction(direction)
    load()
    tiled_direction("Right")
    tiled_direction("Left")
    unload()
    native_direction("Right")
    native_direction("Left")
    load()
    tiled_direction("Right")
    infos = bus("/component/kwin", "org.kde.kglobalaccel.Component", "allShortcutInfos",
                "s", "default", service="org.kde.kglobalaccel")[0]
    infos = {row[0]: row for row in infos}
    for direction, key in [("Left", "H"), ("Down", "J"), ("Up", "K"), ("Right", "L")]:
        assert infos["DirectionalFocus" + direction][6] == [0x10000000 + ord(key)]
        assert infos["KrohnkiteFocus" + direction][6] == []
    print("ROUTER_CHECK PASS shortcut ownership survives disable and re-enable")


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
                    check_focus_lifecycle(root)
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
        # Qt caches the instrumented component across reloads. Run its initial
        # scenarios only once so they cannot interfere with the lifecycle checks.
        checks = Path(__file__).with_suffix(".qml").read_text().replace(
            "running: true", 'running: KWin.readConfig("runFocusTests", true)'
        )
        qml.write_text(source[:source.rfind("}")] + checks + "}\n")
        router = root / "data/kwin/scripts/directional-focus"
        (router / "contents/code").mkdir(parents=True)
        (router / "contents/code/main.js").write_text(
            (Path(__file__).parent.parent / "user/plasma/directional-focus.js").read_text()
        )
        (router / "metadata.json").write_text(json.dumps({
            "KPlugin": {"Id": "directional-focus", "Name": "Directional window focus",
                        "Version": "1.0", "License": "MIT"},
            "X-Plasma-API": "javascript", "X-Plasma-MainScript": "code/main.js",
            "KPackageStructure": "KWin/Script",
        }))
        (root / "config/kwinrc").write_text(
            "[Plugins]\nkrohnkiteEnabled=true\ndirectional-focusEnabled=true\n[Script-krohnkite]\n"
            "threeColumnLayoutOrder=1\ncolumnsLayoutOrder=2\ntileLayoutOrder=3\n"
            "monocleLayoutOrder=4\nfloatingLayoutOrder=5\ndirectionalKeyDwm=false\nrunFocusTests=true\n"
        )
        (root / "config/kglobalshortcutsrc").write_text(
            "[kwin]\n" + "".join(
                f"KrohnkiteFocus{direction}=none,,\n"
                for direction in ["Left", "Down", "Up", "Right"]
            )
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
