"""Run only inside a filesystem/PID/network-isolated bubblewrap desktop."""
import json
import os
import resource
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import time

ROOT = Path('/lab')


def wait_for(predicate, timeout=20):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(.05)
    raise RuntimeError('Private desktop timed out')


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    deps = json.loads((ROOT/'dependencies.json').read_text())
    x11 = deps['desktop'] == 'x11'
    package = Path(deps['package']) if deps['package'] else None
    env = dict(os.environ)
    for name in ('runtime', 'config', 'data', 'cache', 'state', 'home', 'tmp'):
        (ROOT / name).mkdir(mode=0o700, exist_ok=True)
    for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'SESSION_MANAGER'):
        env.pop(key, None)
    env.update(HOME='/home/luke', XDG_RUNTIME_DIR='/lab/runtime', XDG_CONFIG_HOME='/lab/config',
               XDG_DATA_HOME='/lab/data', XDG_CACHE_HOME='/lab/cache', XDG_STATE_HOME='/lab/state',
               DBUS_SYSTEM_BUS_ADDRESS='unix:path=/no-system-bus', QT_QPA_PLATFORM='offscreen',
               KWIN_COMPOSE='Q', QT_QUICK_BACKEND='software', LIBGL_ALWAYS_SOFTWARE='1',
               QT_FORCE_STDERR_LOGGING='1', QT_LOGGING_TO_CONSOLE='1',
               QML_IMPORT_PATH='/run/current-system/sw/lib/qt-6/qml:' + deps['qml'],
               XDG_DATA_DIRS='/run/current-system/sw/share',
               KWIN_SCREENSHOT_NO_PERMISSION_CHECKS='1',
               KWIN_EFFECTS_FORCE_ANIMATIONS='1' if x11 else '0',
               XDG_SESSION_TYPE='x11' if x11 else 'wayland', XDG_CURRENT_DESKTOP='KDE',
               QT_LOGGING_RULES='kwin_scripting.debug=true;js.debug=true;kwin_core.debug=true;kwin_scene_opengl.debug=true',
               T3CODE_HOME='/lab/t3-home', TMPDIR='/lab/tmp')
    env['KDE_DEBUG'] = '1'
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    env['PYTHONPATH'] = str(package/'lib/t3-quake') if package else '/src/pkgs/t3-quake'
    if x11:
        env.update(KWIN_COMPOSE='O2', EGL_PLATFORM='x11', GALLIUM_DRIVER='llvmpipe',
            LD_LIBRARY_PATH=deps['mesa']+'/lib', LIBGL_DRIVERS_PATH=deps['mesa']+'/lib/dri',
            __EGL_VENDOR_LIBRARY_FILENAMES=deps['mesa']+'/share/glvnd/egl_vendor.d/50_mesa.json')
    data = ROOT / 'data/kwin/scripts'
    data.mkdir(parents=True, exist_ok=True)
    shutil.copytree(package/'share/kwin/scripts/t3-quake' if package else '/src/pkgs/t3-quake/kwin',
                    data / 't3-quake', dirs_exist_ok=True)
    shutil.copytree(package/'share/kwin/effects/t3-quake-slide' if package else '/src/pkgs/t3-quake/effect',
                    ROOT / 'data/kwin/effects/t3-quake-slide', dirs_exist_ok=True)
    qml = data/'t3-quake/contents/ui/main.qml'
    qml.chmod(0o600)
    qml.write_text(qml.read_text().replace('function onWindowActivated(window) {',
        'function onWindowActivated(window) { console.log("LAB_FOCUS", root.controller.mode, '
        'window ? String(window.resourceClass) : "none");'))
    shutil.copytree(Path(deps['tiler'])/'share/kwin/scripts/krohnkite' if deps['tiler'] else
                    '/run/current-system/sw/share/kwin/scripts/krohnkite', data / 'krohnkite', dirs_exist_ok=True)
    script_path = data / 'krohnkite/contents/code/script.js'
    for parent in (data / 'krohnkite').rglob('*'):
        if parent.is_dir(): parent.chmod(0o700)
    (data / 'krohnkite').chmod(0o700)
    script_path.chmod(0o600)
    if 'borrowT3Tile(placeholder)' not in script_path.read_text():
        raise RuntimeError('Pass --tiler with the built, patched Krohnkite package')
    (ROOT / 'config/kwinrc').write_text('[Plugins]\nkrohnkiteEnabled=true\nt3-quakeEnabled=true\nt3-quake-slideEnabled=true\n'
        '[Script-krohnkite]\nthreeColumnLayoutOrder=1\ncolumnsLayoutOrder=2\ntileLayoutOrder=3\n'
        'monocleLayoutOrder=4\nfloatingLayoutOrder=5\nnotificationDuration=0\n')
    if x11:
        shutil.copytree(ROOT/'data/kwin', ROOT/'data/kwin-x11', dirs_exist_ok=True)
        shutil.copy(ROOT/'config/kwinrc', ROOT/'config/kwin-x11rc')
    config = ROOT / 'bus.conf'
    config.write_text('<busconfig><type>session</type><listen>unix:path=/lab/runtime/bus</listen>'
                      '<auth>EXTERNAL</auth><policy context="default"><allow send_destination="*"/>'
                      '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
    children = []
    def start(command, name, **kwargs):
        log = (ROOT / (name + '.log')).open('w')
        child = subprocess.Popen(command, env=kwargs.pop('env', env), stdout=log, stderr=log, start_new_session=True, **kwargs)
        log.close()
        children.append(child)
        return child
    try:
        start(['dbus-daemon', '--nofork', '--config-file=' + str(config)], 'bus')
        wait_for(lambda: (ROOT / 'runtime/bus').exists())
        env['DBUS_SESSION_BUS_ADDRESS'] = 'unix:path=/lab/runtime/bus'
        if x11:
            start(['Xvfb', ':99', '-screen', '0', '3200x1000x24', '-nolisten', 'tcp', '-ac'], 'xvfb')
            wait_for(lambda: Path('/tmp/.X11-unix/X99').exists())
            env['DISPLAY'] = ':99'
        if x11:
            env.update(QT_QPA_PLATFORM='xcb', KWIN_OPENGL_INTERFACE='glx', EGL_PLATFORM='x11',
                __GLX_VENDOR_LIBRARY_NAME='mesa')
            start([deps['kwinX11'], '--replace'], 'kwin')
            time.sleep(2)
        else:
            start(['kwin_wayland', '--virtual', '--width', '1600', '--height', '1000', '--output-count', '2',
                   '--socket', 'quake-test', '--no-lockscreen', '--no-kactivities', '--no-global-shortcuts'], 'kwin')
            wait_for(lambda: (ROOT / 'runtime/quake-test').exists())
            env.update(WAYLAND_DISPLAY='quake-test', QT_QPA_PLATFORM='wayland')
            wait_for(lambda: subprocess.run(['qdbus', 'org.kde.KWin', '/KWin', 'supportInformation'],
                env=env, capture_output=True, timeout=3).returncode == 0)
            subprocess.run(['kscreen-doctor', 'output.Virtual-1.position.0,1000',
                'output.Virtual-1.scale.1.25'], env=env, check=True, capture_output=True, timeout=5)
        controller_command = [str(package/'bin/t3-quake-daemon')] if package and not x11 else [sys.executable, '-m', 't3_quake.daemon']
        controller_process = start(controller_command, 'controller')
        (ROOT/'controller.pid').write_text(str(controller_process.pid))
        start([sys.executable, '/src/pkgs/t3-quake/tests/peer.py'], 'peer')
        # The host profile, display sockets, processes, network, and GPU devices
        # do not exist in this namespace. Use the extracted app read-only.
        start(['/app/t3code', '--no-sandbox', '--disable-gpu', '--password-store=basic',
               '--disable-dev-shm-usage', '--ozone-platform=' + ('x11' if x11 else 'wayland')], 't3',
              env=env | {'LD_LIBRARY_PATH': '/usr/lib:/usr/lib64:/app'})
        script = ROOT / 'inspect.js'
        script.write_text('print("LAB_WINDOWS", JSON.stringify(workspace.stackingOrder.map(w => '
                          '({id:String(w.internalId),class:String(w.resourceClass),title:w.caption,'
                          'normal:w.normalWindow,geometry:w.frameGeometry}))));')
        def inspect():
            subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.unloadScript',
                            'lab-inspect'], env=env, capture_output=True)
            loaded = subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.loadScript',
                            str(script), 'lab-inspect'], env=env, capture_output=True)
            if loaded.returncode: return False
            subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.start'],
                           env=env, capture_output=True, check=True)
            text = (ROOT / 'kwin.log').read_text()
            rows = [line.split('LAB_WINDOWS ', 1)[1] for line in text.splitlines() if 'LAB_WINDOWS ' in line]
            return rows and any('t3' in w['class'].lower() for w in json.loads(rows[-1]))
        wait_for(inspect, 60)
        print('PASS: independent T3 window on private headless KWin', flush=True)
        def bridge(action='status'):
            result = subprocess.run(['qdbus', 'io.github.lpke.T3Quake', '/T3Quake',
                'io.github.lpke.T3Quake.Command', action], env=env, capture_output=True, text=True, timeout=3)
            if result.returncode and action == 'status': return {}
            result.check_returncode()
            return json.loads(result.stdout)
        print('BRIDGE', bridge(), flush=True)
        loaded = subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'isScriptLoaded', 't3-quake'],
                                env=env, capture_output=True, text=True)
        print('SCRIPT', loaded.stdout, loaded.stderr, flush=True)
        wait_for(lambda: bridge().get('connected'), 10)
        count = 0
        def evaluate(code, value='true'):
            nonlocal count
            count += 1
            marker = f'LAB_RESULT_{count} '
            script.write_text('var t = workspace.stackingOrder.find(w => /com\\.t3tools\\.T3Code/i.test(String(w.resourceClass)));'
                'var p = workspace.stackingOrder.find(w => String(w.resourceClass) === "t3-quake-placeholder");'
                'var a = workspace.stackingOrder.find(w => String(w.resourceClass) === "quake-test-peer");'
                + code + '\nprint(' + json.dumps(marker.strip()) + ', JSON.stringify(' + value + '));')
            subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.unloadScript',
                            'lab-inspect'], env=env, capture_output=True, check=True)
            subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.loadScript',
                            str(script), 'lab-inspect'], env=env, capture_output=True, check=True)
            subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.start'],
                           env=env, capture_output=True, check=True)
            def result():
                lines = [line.split(marker, 1)[1] for line in (ROOT/'kwin.log').read_text().splitlines() if marker in line]
                return lines and [json.loads(lines[-1])]
            return wait_for(result)[0]
        def snapshot():
            return evaluate('', '({t:t.frameGeometry,a:a.frameGeometry,p:p ? p.frameGeometry : null,'
                'active:workspace.activeWindow ? String(workspace.activeWindow.resourceClass) : null,'
                'desktop:workspace.currentDesktop.id,opacity:t.opacity,above:t.keepAbove})')
        support = subprocess.run(['qdbus', 'org.kde.KWin', '/KWin', 'supportInformation'],
                                 env=env, capture_output=True, text=True)
        (ROOT/'support.txt').write_text(support.stdout + support.stderr)
        if not x11:
            layout = subprocess.run(['kscreen-doctor', '--json'], env=env, capture_output=True, text=True, timeout=5)
            (ROOT/'layout.json').write_text(layout.stdout)
        # Wait for T3's initial renderer and for Krohnkite's first placement.
        wait_for(lambda: 'backend ready' in (ROOT/'t3.log').read_text(), 20)
        time.sleep(.6)
        evaluate('workspace.activeWindow = a;')
        original = snapshot()
        (ROOT/'readiness.json').write_text(json.dumps(evaluate('',
            '({t:t.readyForPainting,a:a.readyForPainting,hidden:t.hidden,buffer:t.bufferGeometry})')))
        (ROOT/'normal.json').write_text(json.dumps(original, indent=2))
        def screenshot(name):
            if x11:
                code = ('from PyQt6.QtGui import QGuiApplication;'
                    'app=QGuiApplication([]);'
                    'app.primaryScreen().grabWindow(0).save(' + repr('/lab/'+name+'.png') + ')')
                subprocess.run([sys.executable, '-c', code], env=env | {'QT_QPA_PLATFORM': 'xcb'}, check=True)
                assert (ROOT/(name+'.png')).exists()
                return
            # Native Wayland runs check compositor state. The installed KWin's
            # QPainter backend does not supply working framebuffer captures.
            return
        if not x11:
            subprocess.run(['kscreen-doctor', '--dpms', 'on'], env=env, capture_output=True, timeout=5)
        time.sleep(1)
        screenshot('normal')
        if x11:
            recorder = start([sys.executable, '/src/pkgs/t3-quake/tests/record.py'], 'record',
                             env=env | {'QT_QPA_PLATFORM': 'xcb'})
            wait_for(lambda: (ROOT/'frames/000.png').exists(), 5)
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'quake', 10)
        print('PASS: quake mode', flush=True)
        if x11:
            recorder.wait(timeout=8)
        borrowed = snapshot()
        (ROOT/'quake.json').write_text(json.dumps(borrowed, indent=2))
        assert borrowed['p'] == original['t'], (original, borrowed)
        assert borrowed['a'] == original['a'], (original, borrowed)
        assert borrowed['active'].lower() == 'com.t3tools.t3code', borrowed
        screenshot('quake')
        # Keyboard or pointer focus on the placeholder must recall T3.
        evaluate('workspace.activeWindow = p;')
        wait_for(lambda: bridge().get('mode') == 'normal', 10)
        recalled = snapshot()
        wait_for(lambda: snapshot()['p'] is None, 3)
        recalled = snapshot()
        assert recalled['t'] == original['t'] and recalled['p'] is None, recalled
        print('PASS: placeholder focus restores the tile', flush=True)
        evaluate('workspace.activeWindow = a;')
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'quake', 10)
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'normal', 10)
        returned = snapshot()
        assert returned['active'] == 'quake-test-peer', returned
        assert returned['desktop'] == original['desktop'] and returned['t'] == original['t'], returned
        print('PASS: returned to normal mode', flush=True)
        if not x11:
            evaluate('workspace.sendClientToScreen(a, workspace.screens[1]); workspace.activeWindow = a;')
            time.sleep(.3)
            bridge('toggle')
            wait_for(lambda: bridge().get('mode') == 'quake', 10)
            assert evaluate('', 't.output === a.output'), 'Quake used the wrong monitor'
            assert evaluate('', 't.frameGeometry.y >= 1000'), 'Quake did not use the stacked output'
            bridge('restore')
            wait_for(lambda: bridge().get('mode') == 'normal', 10)
            print('PASS: focused monitor on mixed-scale stacked outputs', flush=True)
        # The home slot can live on another desktop. Dismissing must not follow it.
        evaluate('workspace.createDesktop(workspace.desktops.length, "Away");'
                 'a.desktops = [workspace.desktops[workspace.desktops.length-1]];'
                 'workspace.currentDesktop = a.desktops[0]; workspace.activeWindow = a;')
        time.sleep(.3)
        away = snapshot()
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'quake', 10)
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'normal', 10)
        away_returned = snapshot()
        assert away_returned['desktop'] == away['desktop'], away_returned
        assert away_returned['active'] == 'quake-test-peer', away_returned
        print('PASS: no desktop switch on return', flush=True)
        evaluate('a.fullScreen = true; workspace.activeWindow = a;')
        time.sleep(.2)
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'quake', 10)
        assert evaluate('', 'a.fullScreen'), 'Fullscreen app lost fullscreen state'
        screenshot('fullscreen-quake')
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'normal', 10)
        assert snapshot()['active'] == 'quake-test-peer'
        print('PASS: fullscreen focus restored', flush=True)
        # Use the real Plasma notification renderer in the private display.
        start(['/run/current-system/sw/libexec/kactivitymanagerd'], 'activities')
        start(['/run/current-system/sw/libexec/kglobalacceld'], 'globalaccel')
        start(['plasmashell', '--no-respawn'], 'plasma')
        def notifications_ready():
            query = subprocess.run(['qdbus', 'org.freedesktop.Notifications',
                '/org/freedesktop/Notifications', 'org.freedesktop.Notifications.GetServerInformation'],
                env=env, capture_output=True, text=True, timeout=3)
            return query.returncode == 0
        wait_for(notifications_ready, 15)
        start([sys.executable, '/src/pkgs/t3-quake/tests/systemd_stub.py'], 'systemd-stub')
        wait_for(lambda: subprocess.run(['qdbus', 'org.freedesktop.systemd1',
            '/org/freedesktop/systemd1'], env=env, capture_output=True, timeout=3).returncode == 0, 5)
        start(['dbus-monitor', "interface='org.freedesktop.Notifications'"], 'notifications')
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'quake', 10)
        if x11:
            controller_process.kill()
        else:
            os.kill(controller_process.pid, signal.SIGSTOP)
        wait_for(lambda: evaluate('', 't.opacity === 1 && !t.keepAbove'), 8)
        time.sleep(3)
        assert evaluate('', 't && !t.deleted && !p'), 'Failed helper retained its placeholder'
        wait_for(lambda: 'Run t3-quake restart to retry.' in (ROOT/'notifications.log').read_text(), 5)
        screenshot('failure-notification')
        if x11:
            subprocess.run([sys.executable, '/src/pkgs/t3-quake/tests/capture_notification.py'],
                env=env | {'QT_QPA_PLATFORM': 'xcb'}, check=True, timeout=8)
        print('PASS: crash restores T3 and emits a system notification', flush=True)
        subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'unloadScript', 't3-quake'],
                       env=env, check=True, capture_output=True, timeout=3)
        controller_process = start(controller_command, 'controller-restarted')
        (ROOT/'controller.pid').write_text(str(controller_process.pid))
        wait_for(lambda: bridge(), 5)
        subprocess.run(['qdbus', 'org.kde.KWin', '/Scripting', 'start'], env=env,
                       check=True, capture_output=True, timeout=3)
        wait_for(lambda: bridge().get('connected'), 10)
        bridge('toggle')
        wait_for(lambda: bridge().get('mode') == 'quake', 10)
        bridge('restore')
        wait_for(lambda: bridge().get('mode') == 'normal', 10)
        print('PASS: recovery reload keeps the same T3 window usable', flush=True)
        evaluate('t.closeWindow();')
        wait_for(lambda: controller_process.poll() is not None, 10)
        print('PASS: helper exits when T3 closes', flush=True)
        controller_process = start(controller_command, 'controller-new-session')
        (ROOT/'controller.pid').write_text(str(controller_process.pid))
        wait_for(lambda: bridge(), 5)
        launcher = Path('/home/luke/.local/bin/t3code')
        launcher.parent.mkdir(parents=True, exist_ok=True)
        launcher.write_text('#!/bin/sh\nexec env LD_LIBRARY_PATH=/usr/lib:/usr/lib64:/app '
            '/app/t3code --no-sandbox --disable-gpu --password-store=basic '
            '--disable-dev-shm-usage --ozone-platform=' + ('x11' if x11 else 'wayland') + '\n')
        launcher.chmod(0o700)
        subprocess.run([sys.executable, '-m', 't3_quake.cli'], env=env,
                       check=True, capture_output=True, timeout=20)
        wait_for(lambda: bridge().get('connected'), 20)
        wait_for(lambda: bridge().get('mode') == 'quake', 10)
        bridge('restore')
        wait_for(lambda: bridge().get('mode') == 'normal', 10)
        evaluate('t.closeWindow();')
        wait_for(lambda: controller_process.poll() is not None, 10)
        print('PASS: new T3 session attaches without restarting KWin', flush=True)
        (ROOT / 'isolation-result.json').write_text(json.dumps({'t3_mapped': True, 'cpus': sorted(os.sched_getaffinity(0)),
            'display': env.get('WAYLAND_DISPLAY', env.get('DISPLAY')), 'profile': env['T3CODE_HOME']}, indent=2))
    finally:
        for child in reversed(children):
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()


if __name__ == '__main__':
    main()
