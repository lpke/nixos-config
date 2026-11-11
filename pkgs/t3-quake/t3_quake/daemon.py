"""A disposable placeholder and bounded D-Bus bridge; never owns T3's process."""
import json
import sys
import time
import uuid

from PyQt6.QtCore import QObject, Qt, QTimer, pyqtClassInfo, pyqtSlot
from PyQt6.QtDBus import QDBusConnection
from PyQt6.QtWidgets import QApplication, QLabel, QVBoxLayout, QWidget

SERVICE = 'io.github.lpke.T3Quake'


class Placeholder(QWidget):
    def __init__(self, window_id, geometry):
        super().__init__()
        self.setWindowTitle('T3 quake · ' + window_id)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating)
        self.setAttribute(Qt.WidgetAttribute.WA_DeleteOnClose)
        self.setStyleSheet('QWidget { background: #202326; color: #e5e7eb; }'
                           'QLabel { background: transparent; }')
        layout = QVBoxLayout(self)
        layout.addStretch()
        title = QLabel('T3 Code')
        title.setStyleSheet('font-size: 24px; font-weight: 600;')
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        text = QLabel('Open in drop-down mode\nFocus this window to bring it back.')
        text.setStyleSheet('font-size: 15px; color: #a9afb6;')
        text.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(text)
        layout.addStretch()
        self.resize(round(geometry['width']), round(geometry['height']))
        self.show()


@pyqtClassInfo('D-Bus Interface', SERVICE)
class Bridge(QObject):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.placeholder = None
        self.sequence = 0
        self.action = None
        self.state = {'mode': 'waiting'}
        self.seen = time.monotonic()
        self.connected = False
        self.instance = str(uuid.uuid4())
        self.timer = QTimer(self)
        self.timer.setInterval(1000)
        self.timer.timeout.connect(self.watchdog)
        self.timer.start()

    @pyqtSlot(str, result=str)
    def Exchange(self, message):
        try:
            data = json.loads(message)
            if not isinstance(data, dict):
                raise ValueError('Invalid compositor message')
            if not isinstance(data.get('id'), str) or data.get('mode') not in (
                    'normal', 'placeholder', 'sizing', 'opening', 'quake', 'closing', 'return-sizing'):
                raise ValueError('Invalid compositor state')
            self.seen = time.monotonic()
            self.connected = True
            self.state = {'mode': data['mode'], 'id': data['id']}
            request = data.get('request') or {}
            if 'placeholder' in request and self.placeholder is None:
                item = request['placeholder']
                self.placeholder = Placeholder(item['id'], item['geometry'])
                self.placeholder.destroyed.connect(self.clear_placeholder)
            if data['mode'] == 'normal' and self.placeholder is not None:
                self.placeholder.close()
            command = {'sequence': self.sequence, 'action': self.action, 'instance': self.instance, 'id': data['id']}
            self.action = None
            return json.dumps(command)
        except (ValueError, KeyError, TypeError) as error:
            print(f'T3 quake: {error}', file=sys.stderr, flush=True)
            return json.dumps({'error': str(error)})

    def clear_placeholder(self):
        self.placeholder = None

    @pyqtSlot(str, result=str)
    def Command(self, action):
        if action not in ('toggle', 'restore', 'status'):
            return json.dumps({'error': 'Unknown command'})
        if action != 'status':
            self.sequence += 1
            self.action = None if action == self.action == 'toggle' else action
        return json.dumps(self.state | {'connected': self.connected,
                                      'heartbeat_age': time.monotonic() - self.seen})

    @pyqtSlot()
    def Stop(self):
        QTimer.singleShot(0, self.app.quit)

    def watchdog(self):
        # No leaked helper if T3/KWin disappears. D-Bus releases with this process.
        timeout = 3 if self.connected else 30
        if time.monotonic() - self.seen > timeout:
            self.app.quit()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName('t3-quake-placeholder')
    app.setDesktopFileName('t3-quake-placeholder')
    app.setQuitOnLastWindowClosed(False)
    bridge = Bridge(app)
    bus = QDBusConnection.sessionBus()
    if not bus.registerService(SERVICE):
        raise SystemExit('T3 quake controller is already running or D-Bus is unavailable')
    if not bus.registerObject('/T3Quake', bridge, QDBusConnection.RegisterOption.ExportAllSlots):
        raise SystemExit('Could not register the T3 quake controller')
    raise SystemExit(app.exec())


if __name__ == '__main__':
    main()
