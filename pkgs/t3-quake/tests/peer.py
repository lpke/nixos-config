"""A normal disposable window for the private compositor's focus/layout tests."""
import sys
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QApplication, QLabel

app = QApplication(sys.argv)
app.setApplicationName('quake-test-peer')
app.setDesktopFileName('quake-test-peer')
window = QLabel('Workspace\n\nA separate application stays here while T3 is borrowed.')
window.setWindowTitle('Workspace')
window.setAlignment(Qt.AlignmentFlag.AlignCenter)
window.setStyleSheet('background:#17232d;color:#dce5ec;font:18px sans-serif;')
window.resize(700, 700)
window.show()
app.exec()
