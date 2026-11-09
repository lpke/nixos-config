"""Native Qt menus; names are shared verbatim with the output labels."""

from pathlib import Path

from PyQt6.QtGui import QActionGroup
from PyQt6.QtWidgets import QMenu, QSystemTrayIcon
from tray_icon import primary_click_opens_menu, svg_icon

from .state import ALL


# Plasma imports menu labels over D-Bus; spaces preserve the native arrow gutter.
MENU_RIGHT_GUTTER = "\u00a0" * 3


class Tray:
    def __init__(self, state, dispatch):
        self.state = state
        self.dispatch = dispatch
        self.menu = QMenu()
        self.blackout = self.menu.addMenu("Black out" + MENU_RIGHT_GUTTER)
        self.hotkey = self.menu.addMenu("Black out hotkey monitor" + MENU_RIGHT_GUTTER)
        self.menu.addAction("Label monitors", lambda: dispatch("label"))
        self.menu.addAction("Quit", lambda: dispatch("quit"))
        self.icon = QSystemTrayIcon(svg_icon(Path(__file__).with_name("monitor.svg")))
        self.icon.setToolTip("Monitor control")
        self.icon.setContextMenu(self.menu)
        primary_click_opens_menu(self.icon)
        self.menu.aboutToShow.connect(self.populate)
        self.icon.show()
        self.populate()

    def populate(self):
        self.dispatch("refresh")
        self.blackout.clear()
        self.hotkey.clear()
        if hasattr(self, "target_group"):
            self.target_group.deleteLater()
        self.target_group = QActionGroup(self.hotkey)
        self.target_group.setExclusive(True)
        self.black_actions = {}
        self.target_actions = {}
        entries = [(ALL, "All monitors", bool(self.state.eligible))]
        entries.extend((output.name, output.title, output.active)
                       for output in self.state.outputs.values())
        for name, title, active in entries:
            text = title.replace("&", "&&")
            action = self.blackout.addAction(text)
            action.setCheckable(True)
            action.setEnabled(active)
            action.triggered.connect(lambda checked, target=name: self.dispatch("toggle", target))
            self.black_actions[name] = action
            target = self.hotkey.addAction(text)
            target.setCheckable(True)
            self.target_group.addAction(target)
            target.triggered.connect(lambda checked, name=name: self.dispatch("select", name))
            self.target_actions[name] = target
        self.sync()

    def sync(self):
        for name, action in self.black_actions.items():
            action.setChecked(self.state.all_black if name == ALL else name in self.state.blacked)
        for name, action in self.target_actions.items():
            action.setChecked(name == self.state.target)

    def error(self, message):
        self.icon.showMessage("Monitor control", message, QSystemTrayIcon.MessageIcon.Warning, 5000)
