"""Construct a QML window with an explicit native Wayland output binding."""

from pathlib import Path

from PyQt6.QtCore import QUrl
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickWindow


def create_surface(screen):
    engine = QQmlApplicationEngine()
    # QML Window.screen exposes QQuickScreenInfo. LayerShell needs the actual
    # QScreen QObject, including for outputs away from (0, 0) or at other scales.
    engine.rootContext().setContextProperty("targetScreen", screen)
    engine.load(QUrl.fromLocalFile(str(Path(__file__).with_name("overlay.qml"))))
    if not engine.rootObjects():
        raise RuntimeError("Could not load Monitor control overlay")
    window = engine.rootObjects()[0]
    if not isinstance(window, QQuickWindow):
        raise RuntimeError("Monitor control overlay is not a Qt Quick window")
    window.setScreen(screen)
    window.setPosition(screen.geometry().topLeft())
    window.resize(screen.size())
    return engine, window
