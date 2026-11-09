"""Real layer-shell/QML acceptance on an owned private bus and headless KWin.

Uses QPainter because the host's render device cannot initialize isolated EGL.
PNG artifacts are QQuickWindow.grabWindow() of the actual production QML, mapped
on the private compositor. They are not full-compositor screenshots.
"""
import argparse
import configparser
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import select
import shlex
import signal
import socket
import subprocess
import tempfile
import time


def wait_for(predicate, timeout=8, pump=None):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if pump:
            pump()
        result = predicate()
        if result:
            return result
        time.sleep(.03)
    raise AssertionError("Timed out waiting for isolated test state")


def request(runtime, command, target=None, expect_ok=True):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(8)
        connection.connect(str(runtime / "monitor-control/controller.sock"))
        connection.sendall(json.dumps({"command": command, "target": target}).encode() + b"\n")
        data = b""
        while b"\n" not in data:
            chunk = connection.recv(65536)
            if not chunk:
                raise AssertionError("Controller disconnected")
            data += chunk
        result = json.loads(data)
        assert result["ok"] == expect_ok, result
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kwin", required=True)
    parser.add_argument("--daemon", required=True)
    parser.add_argument("--layer-import", required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--hotkey-desktop", type=Path,
                        help="Also execute this installed desktop action against the private controller")
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=True)
    processes = []
    logs = []
    with tempfile.TemporaryDirectory(prefix="monitor-control-acceptance-") as directory:
        root = Path(directory)
        runtime = root / "runtime"
        runtime.mkdir(mode=0o700)
        env = os.environ.copy()
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "SESSION_MANAGER", "DBUS_SESSION_BUS_ADDRESS",
                    "LD_LIBRARY_PATH", "EGL_PLATFORM"):
            env.pop(key, None)
        env.update(XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(root / "config"),
                   XDG_CACHE_HOME=str(root / "cache"), XDG_DATA_HOME=str(root / "data"),
                   QT_QPA_PLATFORM="offscreen", KWIN_COMPOSE="Q", QT_FORCE_STDERR_LOGGING="1",
                   QT_QUICK_BACKEND="software", QML_IMPORT_PATH=args.layer_import)
        bus_config = root / "dbus.conf"
        bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>'
                              '<auth>EXTERNAL</auth><policy context="default">'
                              '<allow send_destination="*"/><allow receive_sender="*"/>'
                              '<allow own="*"/></policy></busconfig>')
        bus = subprocess.Popen(["dbus-daemon", "--nofork", "--print-address=1",
                                f"--config-file={bus_config}"], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        processes.append(bus)
        assert select.select([bus.stdout], [], [], 5)[0], "Private bus failed to start"
        env["DBUS_SESSION_BUS_ADDRESS"] = bus.stdout.readline().strip()
        try:
            log = (args.artifacts / "kwin.log").open("w")
            logs.append(log)
            kwin = subprocess.Popen([args.kwin, "--virtual", "--output-count", "2", "--width", "1280",
                                     "--height", "900", "--no-lockscreen", "--no-global-shortcuts",
                                     "--no-kactivities", "--socket", "monitor-acceptance"],
                                    env=env, stdout=log, stderr=log)
            processes.append(kwin)
            wait_for(lambda: (runtime / "monitor-acceptance").exists())
            env.update(QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY="monitor-acceptance")
            os.environ.update(env)
            os.environ["WAYLAND_DEBUG"] = "1"
            # Qt is initialized only after replacing the runtime, bus and socket.
            from PyQt6.QtCore import QPoint, Qt
            from PyQt6.QtWidgets import QApplication
            from monitor_control.surface import create_surface
            from monitor_control.state import Output, State
            from monitor_control.tray import Tray
            app = QApplication([])
            app.setQuitOnLastWindowClosed(False)

            def pump(duration=.1):
                deadline = time.monotonic() + duration
                while time.monotonic() < deadline:
                    app.processEvents()
                    time.sleep(.005)

            def configure(*settings):
                result = subprocess.run(["kscreen-doctor", *settings], env=env, capture_output=True,
                                        text=True, timeout=10)
                assert result.returncode == 0, result.stderr
                pump(.3)

            def layout():
                result = subprocess.run(["kscreen-doctor", "--json"], env=env, capture_output=True,
                                        text=True, check=True, timeout=10)
                return json.loads(result.stdout)

            names = [item["name"] for item in layout()["outputs"]]
            first, second = names
            configure(f"output.{first}.position.-800,-200", f"output.{second}.position.480,120",
                      f"output.{second}.scale.1.5")
            actual_layout = layout()
            (args.artifacts / "layout.json").write_text(json.dumps(actual_layout, indent=2))
            assert sorted(item["scale"] for item in actual_layout["outputs"]) == [1, 1.5]
            assert len({(item["pos"]["x"], item["pos"]["y"]) for item in actual_layout["outputs"]}) == 2
            log = (args.artifacts / "controller.log").open("w")
            logs.append(log)
            daemon_env = dict(env, WAYLAND_DEBUG="1")
            daemon = subprocess.Popen([args.daemon], env=daemon_env, stdout=log, stderr=log)
            processes.append(daemon)
            wait_for(lambda: (runtime / "monitor-control/controller.sock").exists())
            call = lambda command="status", target=None: request(runtime, command, target)
            def hotkey():
                if args.hotkey_desktop:
                    desktop = configparser.ConfigParser(interpolation=None)
                    desktop.read(args.hotkey_desktop)
                    command = shlex.split(desktop["Desktop Action toggle-blackout"]["Exec"])
                    assert command[-1] == "toggle", command
                    # Even the installed CLI receives only our private socket,
                    # bus and settings. No live shortcut or screen is invoked.
                    subprocess.run(command, env=env, check=True, capture_output=True, text=True, timeout=10)
                    return call()
                return call("toggle")
            initial = call()
            assert initial["hotkey_monitor"] == "all" and not initial["blacked_out"], initial
            assert {item["name"] for item in initial["outputs"]} == set(names), initial
            titles = {item["name"]: item["title"] for item in initial["outputs"]}
            (args.artifacts / "menu-names.json").write_text(json.dumps(titles, indent=2))
            menu_state = State(root / "menu-settings.json")
            menu_state.refresh([Output(item["name"], item["title"], item["active"])
                                for item in initial["outputs"]])
            menu_state.blacked = {first}
            menu = Tray(menu_state, lambda *_: None)
            for title, widget in (("menu", menu.menu), ("blackout-menu", menu.blackout),
                                  ("hotkey-menu", menu.hotkey)):
                widget.ensurePolished()
                widget.adjustSize()
                assert widget.grab().save(str(args.artifacts / f"{title}.png"))
            menu.icon.hide()
            # Sample the production animation on both real native output-bound
            # surfaces. Mac uses the same 250 ms smoothstep and distance-scaled
            # reversal; a cover must stay mapped until its fade-out completes.
            fade_measurements = {}
            for screen in app.screens():
                engine, window = create_surface(screen)
                window.setProperty("covered", True)
                pump(.08)
                assert 0 < window.property("coverOpacity") < 1
                wait_for(lambda: window.property("coverOpacity") == 1, pump=app.processEvents)
                started = time.monotonic()
                window.setProperty("covered", False)
                pump(.08)
                interrupted = window.property("coverOpacity")
                assert 0 < interrupted < 1 and window.isVisible()
                window.setProperty("covered", True)
                assert window.property("coverOpacity") == interrupted
                wait_for(lambda: window.property("coverOpacity") == 1, pump=app.processEvents)
                assert window.isVisible(), "A stale fade-out removed the reversed cover"
                started = time.monotonic()
                window.setProperty("covered", False)
                wait_for(lambda: window.property("coverOpacity") == 0, pump=app.processEvents)
                elapsed = time.monotonic() - started
                assert .20 <= elapsed <= .40, elapsed
                assert not window.isVisible()
                fade_measurements[screen.name()] = elapsed
                window.close()
                del window, engine
            assert call("toggle", first)["blacked_out"] == [first]
            wait_for(lambda: call()["overlays"].get(first, {}).get("rendered"))
            assert call()["overlays"][first]["screen"] == first
            assert hotkey()["all_black"]  # Partial All fills remaining.
            status = wait_for(lambda: (status := call())["overlays"] and
                              len(status["overlays"]) == 2 and
                              all(item["rendered"] for item in status["overlays"].values()) and status)
            assert all(name == item["screen"] for name, item in status["overlays"].items()), status
            children = Path(f"/proc/{daemon.pid}/task/{daemon.pid}/children")
            worker = next(pid for pid in children.read_text().split()
                          if Path(f"/proc/{pid}/cmdline").read_bytes().rstrip(b"\x00").endswith(first.encode()))
            os.kill(int(worker), signal.SIGKILL)
            wait_for(lambda: call()["blacked_out"] == [second])
            assert set(call()["overlays"]) == {second}
            assert call("toggle")["all_black"]
            wait_for(lambda: all(item["rendered"] for item in call()["overlays"].values()))
            assert hotkey()["blacked_out"] == []  # All black restores.
            assert call("toggle", second)["blacked_out"] == [second]
            assert call("toggle", first)["all_black"]
            assert call("toggle", second)["blacked_out"] == [first]
            started = time.monotonic()
            call("label")
            wait_for(lambda: len(call()["overlays"]) == 2 and
                     all(item["rendered"] for item in call()["overlays"].values()))
            # Load production surfaces alongside the controller, on the same
            # private outputs, to capture actual Qt Quick-rendered label PNGs.
            surfaces = {}
            finished = []
            for screen in app.screens():
                engine, window = create_surface(screen)
                name = screen.name()
                surfaces[name] = (engine, window)
                window.setProperty("monitorName", titles[name])
                window.setProperty("covered", name == first)
                window.labelFinished.connect(lambda name=name: finished.append(name))
                # Prove explicit native output binding with a negative initial
                # Qt origin, even though KWin normalizes enabled output origins.
                window.setPosition(QPoint(-800, -200) if name == second else screen.geometry().topLeft())
                window.showLabel()
            pump(.3)
            for name, (_, window) in surfaces.items():
                image = window.grabWindow()
                assert not image.isNull(), name
                image.save(str(args.artifacts / f"label-{name}.png"))
                assert window.screen().name() == name
                if name == second:
                    assert window.flags() & Qt.WindowType.WindowTransparentForInput
                assert window.flags() & Qt.WindowType.WindowDoesNotAcceptFocus
                # Analyze in logical pixels to make fractional scale comparable.
                sample = image.scaled(window.width(), window.height())
                white = [(x, y) for y in range(sample.height()) for x in range(sample.width())
                         if sample.pixelColor(x, y).red() > 240 and
                         sample.pixelColor(x, y).green() > 240 and sample.pixelColor(x, y).blue() > 240]
                assert len(white) > 1000, f"Missing label border/text: {name}"
                left, right = min(x for x, _ in white), max(x for x, _ in white)
                top, bottom = min(y for _, y in white), max(y for _, y in white)
                assert abs((left + right) / 2 - sample.width() / 2) < 3
                assert abs((top + bottom) / 2 - sample.height() / 2) < 3
                assert sample.pixelColor(left + 2, (top + bottom) // 2).red() > 240
                assert sample.pixelColor(left + 12, top + 12).value() == 0
                # Exact text comes from the same title as the connected menu.
                assert window.property("monitorName") == titles[name]
            remaining = 4.5 - (time.monotonic() - started)
            assert remaining > 0, "Visual assertions consumed label hold interval"
            pump(remaining)
            assert all(item["labeling"] for item in call()["overlays"].values())
            assert all(window.property("labeling") for _, window in surfaces.values())
            wait_for(lambda: len(finished) == 2, pump=app.processEvents)
            wait_for(lambda: not any(item["labeling"] for item in call()["overlays"].values()))
            assert time.monotonic() - started >= 5
            assert call()["blacked_out"] == [first]
            assert set(call()["overlays"]) == {first}
            black = surfaces[first][1].grabWindow()
            black.save(str(args.artifacts / "after-label-still-black.png"))
            assert black.pixelColor(black.width() // 2, black.height() // 2).value() == 0
            assert not surfaces[second][1].isVisible()
            for engine, window in surfaces.values():
                window.hide()
            call("restore")
            with ThreadPoolExecutor(max_workers=8) as pool:
                list(pool.map(lambda _: call("toggle", first), range(20)))
            assert call()["blacked_out"] == []
            children = Path(f"/proc/{daemon.pid}/task/{daemon.pid}/children")
            wait_for(lambda: not children.read_text().strip())
            call("select", second)
            assert call("toggle")["blacked_out"] == [second]
            wait_for(lambda: call()["overlays"].get(second, {}).get("rendered"))
            worker_pids = children.read_text().split()
            call("quit")
            daemon.wait(timeout=5)
            assert daemon.returncode == 0
            assert all(not Path(f"/proc/{pid}").exists() for pid in worker_pids), worker_pids
            daemon = subprocess.Popen([args.daemon], env=daemon_env, stdout=log, stderr=log)
            processes.append(daemon)
            def reopened():
                try:
                    return call()
                except (FileNotFoundError, ConnectionRefusedError):
                    return None
            status = wait_for(reopened)
            assert status["hotkey_monitor"] == second and status["blacked_out"] == []
            assert call("toggle")["blacked_out"] == [second]
            wait_for(lambda: call()["overlays"].get(second, {}).get("rendered"))
            configure(f"output.{second}.disable")
            pump(.3)
            result = request(runtime, "toggle", expect_ok=False)
            assert "unavailable" in result["error"], result
            assert call()["blacked_out"] == []
            call("quit")
            daemon.wait(timeout=5)
            protocol = (args.artifacts / "controller.log").read_text()
            assert "get_layer_surface" in protocol and "set_keyboard_interactivity(0)" in protocol
            assert ".activate(" not in protocol and ".grab(" not in protocol
            assert "set_keyboard_interactivity(1)" not in protocol
            assert "set_keyboard_interactivity(2)" not in protocol
            report = {"passed": True, "outputs": names, "titles": titles,
                      "fade_out_seconds": fade_measurements,
                      "installed_hotkey_action_tested": bool(args.hotkey_desktop),
                      "checks": ["real layer-shell rendered-output binding", "independent covers",
                                 "250 ms smoothstep fades and interrupted reversal on both outputs",
                                 "All none/partial/all", "production QML PNGs at scale 1 and 1.5",
                                 "label text/border/centering and transparent input flags",
                                 "five-second hold/fade/disposal", "underlying blackout retained",
                                 "20 concurrent IPC toggles", "worker failure isolation",
                                 "Quit cleanup/reopen/persistence",
                                 "disabled target never retargets"],
                      "negative_origin": "KWin normalizes enabled output origins; a production QML surface was also mapped with a negative initial Qt position and explicit native output binding",
                      "capture": "QQuickWindow.grabWindow of production QML on private headless QPainter KWin; not full-compositor screenshots"}
            (args.artifacts / "report.json").write_text(json.dumps(report, indent=2))
            print(json.dumps(report, indent=2))
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
            for log in logs:
                log.close()


if __name__ == "__main__":
    main()
