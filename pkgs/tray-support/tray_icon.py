"""Expose an SVG filename so Plasma renders at its own screen's pixel ratio."""

import hashlib
import os
from pathlib import Path
import tempfile

from PyQt6.QtCore import QByteArray, QRectF, QSize, Qt
from PyQt6.QtGui import QIcon, QIconEngine, QPainter, QPixmap
from PyQt6.QtSvg import QSvgRenderer


ICON_SIZES = (*range(16, 65), 80, 96, 128, 256)


def cached_svg(data):
    directory = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "tray-icons"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = directory / (hashlib.sha256(data).hexdigest() + ".svg")
    if not path.exists() or path.read_bytes() != data:
        with tempfile.NamedTemporaryFile(dir=directory, suffix=".svg", delete=False) as temporary:
            temporary.write(data)
            temporary_path = Path(temporary.name)
        temporary_path.replace(path)
    return path


class SvgTrayIconEngine(QIconEngine):
    def __init__(self, data, path):
        super().__init__()
        self.data = data
        self.path = path
        self.renderer = QSvgRenderer(QByteArray(data))
        if not self.renderer.isValid():
            raise ValueError("Invalid tray SVG")

    def clone(self):
        return SvgTrayIconEngine(self.data, self.path)

    def iconName(self):
        # KDE's platform tray forwards this as StatusNotifierItem.IconName.
        # Plasma accepts absolute SVG paths and renders them at the panel's own
        # DPR. Raster export otherwise uses the application's highest DPR, which
        # can double every advertised size on a mixed-DPI desktop.
        return str(self.path)

    def availableSizes(self, mode=QIcon.Mode.Normal, state=QIcon.State.Off):
        return [QSize(size, size) for size in ICON_SIZES]

    def paint(self, painter, rect, mode, state):
        self.renderer.render(painter, QRectF(rect))

    def pixmap(self, size, mode, state):
        pixmap = QPixmap(size)
        pixmap.fill(Qt.GlobalColor.transparent)
        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.paint(painter, pixmap.rect(), mode, state)
        painter.end()
        return pixmap

    def scaledPixmap(self, size, mode, state, scale):
        pixmap = self.pixmap(size, mode, state)
        pixmap.setDevicePixelRatio(scale)
        return pixmap


def svg_icon(source):
    data = source.read_bytes() if isinstance(source, Path) else source
    if isinstance(data, str):
        data = data.encode()
    # Validate before publishing a cache file. QIconEngine ownership transfers
    # to QIcon; its clone keeps the source bytes and immutable filename.
    if not QSvgRenderer(QByteArray(data)).isValid():
        raise ValueError("Invalid tray SVG")
    return QIcon(SvgTrayIconEngine(data, cached_svg(data)))
