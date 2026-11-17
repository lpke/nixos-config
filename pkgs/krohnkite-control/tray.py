"""Krohnkite controls using the same native Qt tray renderer as the other trays."""

import json
from pathlib import Path
import signal
import sys

from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon
from tray_icon import primary_click_opens_menu, svg_icon


class Tray:
    def __init__(self, app):
        self.app = app
        self.processes = set()
        self.polling = False
        self.pending = None
        self.closing = False
        self.state = {'running': False, 'status': 'Checking'}
        self.error = ''
        self.status_error = ''
        source = Path(__file__).with_name('tiling.svg').read_text()
        # Neutral grey for stopped; match the other trays' error red.
        self.icons = {color: svg_icon(source.replace('#ffffff', color))
                      for color in ('#ffffff', '#808080', '#da4453')}
        self.displayed_icon = None
        self.tray = QSystemTrayIcon(app)
        self.menu = QMenu()
        self.summary = self.menu.addAction('Krohnkite: Checking')
        self.summary.setEnabled(False)
        self.menu.addSeparator()
        self.actions = {}
        for action, title in [('start', 'Start'), ('stop', 'Stop'),
                              ('reload', 'Reload settings'), ('restart', 'Restart'),
                              ('recover', 'Recover KWin scripts')]:
            self.actions[action] = self.menu.addAction(title, lambda checked=False, a=action: self.command(a))
        self.menu.addSeparator()
        self.menu.addAction('Help', lambda: self.command('help'))
        self.quit_action = self.menu.addAction('Quit Krohnkite', lambda: self.command('quit'))
        self.tray.setContextMenu(self.menu)
        primary_click_opens_menu(self.tray)
        self.menu.aboutToShow.connect(self.poll)
        self.tray.show()
        self.timer = QTimer(app)
        self.timer.timeout.connect(self.poll)
        self.timer.start(2000)
        app.aboutToQuit.connect(self.shutdown)
        self.display()
        self.poll()

    def display(self):
        status = {'start': 'Starting', 'stop': 'Stopping', 'reload': 'Reloading',
                  'restart': 'Restarting', 'recover': 'Recovering', 'quit': 'Quitting'}.get(self.pending)
        status = status or self.state['status']
        self.summary.setText(f'Krohnkite: {status}')
        error = self.status_error or self.error
        self.tray.setToolTip(f'Krohnkite: {status}' + (f'\n{error}' if error else ''))
        color = '#da4453' if error or self.state['status'] == 'Unavailable' else (
            '#ffffff' if self.state['running'] else '#808080')
        if color != self.displayed_icon:
            self.tray.setIcon(self.icons[color])
            self.displayed_icon = color
        available = self.state['status'] in ('Running', 'Stopped') and self.pending is None
        for action, item in self.actions.items():
            item.setEnabled(available and (not self.state['running'] if action == 'start' else self.state['running']))
        self.quit_action.setEnabled(self.pending is None)

    def command(self, action):
        if self.closing or (self.pending and action != 'help'):
            return
        if action != 'help':
            self.pending = action
            self.display()
        self.run([action], polling=False, action=action)

    def poll(self):
        if self.closing or self.polling:
            return
        self.polling = True
        self.run(['status', '--json'], polling=True)

    def run(self, arguments, polling=False, action=None):
        process = QProcess(self.app)
        self.processes.add(process)
        timeout = QTimer(process)
        timeout.setSingleShot(True)
        expired = False

        def expire():
            nonlocal expired
            expired = True
            process.kill()

        def finish(code, *_):
            timeout.stop()
            error = bytes(process.readAllStandardError()).decode(errors='replace').strip()
            if code and not error:
                error = process.errorString()
            if expired:
                error = 'Krohnkite command timed out.'
            if polling:
                self.polling = False
                try:
                    if code or expired:
                        raise ValueError(error or 'Could not read Krohnkite status.')
                    state = json.loads(bytes(process.readAllStandardOutput()).decode())
                    if not isinstance(state, dict) or state.get('status') not in ('Running', 'Stopped', 'Unavailable') or not isinstance(state.get('running'), bool):
                        raise ValueError('Invalid Krohnkite status.')
                    self.state = state
                    self.status_error = ''
                except (ValueError, TypeError) as failure:
                    self.state = {'running': False, 'status': 'Unavailable'}
                    self.status_error = str(failure)
            else:
                if action != 'help':
                    self.pending = None
                self.error = error if code or expired else ''
                if self.error:
                    self.tray.showMessage('Krohnkite', self.error, QSystemTrayIcon.MessageIcon.Warning)
            self.processes.discard(process)
            process.deleteLater()
            self.display()
            if not polling and not self.closing:
                self.poll()

        def failed(error):
            if error == QProcess.ProcessError.FailedToStart:
                finish(1)

        timeout.timeout.connect(expire)
        process.finished.connect(finish)
        process.errorOccurred.connect(failed)
        process.start('krohnkite', arguments)
        if action != 'help':
            timeout.start(6000 if polling else 45000)

    def shutdown(self):
        self.closing = True
        self.timer.stop()
        for process in tuple(self.processes):
            process.blockSignals(True)
            if process.state() != QProcess.ProcessState.NotRunning:
                process.kill()
                process.waitForFinished(1000)
        self.processes.clear()
        self.tray.hide()
        # ExecStopPost also runs after SIGKILL, and owns tiler cleanup.


def main():
    app = QApplication(sys.argv)
    app.setApplicationName('krohnkite')
    app.setApplicationDisplayName('Krohnkite')
    app.setDesktopFileName('krohnkite')
    app.setQuitOnLastWindowClosed(False)
    tray = Tray(app)
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: app.quit())
    app.exec()
    del tray


if __name__ == '__main__':
    main()
