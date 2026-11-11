"""Capture the private Xvfb framebuffer, never a user's display."""
import os
from pathlib import Path
import sys
from PyQt6.QtCore import QTimer
from PyQt6.QtGui import QGuiApplication

if os.environ.get('DISPLAY') != ':99' or os.environ.get('XDG_RUNTIME_DIR') != '/lab/runtime':
    raise SystemExit('Only the private test display may be recorded')
app = QGuiApplication(sys.argv)
root = Path('/lab/frames')
root.mkdir(exist_ok=True)
count = 0


def capture():
    global count
    app.primaryScreen().grabWindow(0).save(str(root/f'{count:03d}.png'))
    count += 1
    if count >= 30:
        app.quit()


timer = QTimer()
timer.timeout.connect(capture)
timer.start(16)
app.exec()
