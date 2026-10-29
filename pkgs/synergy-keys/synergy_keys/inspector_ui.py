"""A local, opt-in shortcut inspector. Captures only events delivered to its field."""

import sys

from PyQt6.QtCore import QEvent, Qt, QThread, pyqtSignal
from PyQt6.QtGui import QDesktopServices, QKeySequence
from PyQt6.QtWidgets import (
    QApplication, QComboBox, QHBoxLayout, QLabel, QLineEdit, QListWidget,
    QListWidgetItem, QPushButton, QSplitter, QVBoxLayout, QWidget,
)

from .chords import parse
from .inspector_search import Catalog
from .inspector_sources import Sources
from .inspector_view import TraceView


class ShortcutInput(QLineEdit):
    captured = pyqtSignal(str)
    captureFinished = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.capturing = False
        self.setPlaceholderText("Search shortcuts or actions: thumb+l, command-m, grow window…")

    def capture(self, enabled):
        self.capturing = enabled
        self.setReadOnly(enabled)
        self.setPlaceholderText("Press a shortcut here…" if enabled else
                                "Search shortcuts or actions: thumb+l, command-m, grow window…")
        if enabled:
            self.clear()
            self.setFocus()

    def event(self, event):
        if self.capturing and event.type() == QEvent.Type.ShortcutOverride:
            event.accept()
            return True
        # Handle Tab here too; QWidget normally treats it as focus navigation.
        if self.capturing and event.type() == QEvent.Type.KeyPress:
            modifiers = []
            for flag, name in [(Qt.KeyboardModifier.ControlModifier, "Ctrl"), (Qt.KeyboardModifier.AltModifier, "Alt"),
                               (Qt.KeyboardModifier.ShiftModifier, "Shift"), (Qt.KeyboardModifier.MetaModifier, "Meta")]:
                if event.modifiers() & flag:
                    modifiers.append(name)
            if event.key() in {Qt.Key.Key_Control, Qt.Key.Key_Shift, Qt.Key.Key_Alt, Qt.Key.Key_Meta, Qt.Key.Key_AltGr}:
                return True
            key = QKeySequence(event.key()).toString(QKeySequence.SequenceFormat.PortableText)
            key = {"+": "plus", "-": "minus"}.get(key, key)
            text = "+".join([*modifiers, key])
            try:
                parse(text)
            except ValueError:
                self.setText(f"Unsupported captured key: {key}. Enter its name instead.")
            else:
                self.setText(text)
                self.captured.emit(text)
            self.capture(False)
            self.captureFinished.emit()
            event.accept()
            return True
        return super().event(event)


class SourceLoader(QThread):
    loaded = pyqtSignal(object)
    failed = pyqtSignal(str)

    def run(self):
        try:
            sources = Sources()
            catalogs = {device: Catalog(sources, device) for device in ["Keyboard", "Logitech G903"]}
            self.loaded.emit((sources, catalogs))
        except Exception as error:
            self.failed.emit(str(error))


class InspectorWindow(QWidget):
    def __init__(self, query="", catalogs=None):
        super().__init__()
        self.catalogs = catalogs or {}
        self.loader = None
        QApplication.instance().aboutToQuit.connect(self.wait_for_loader)
        self.setWindowTitle("Synergy shortcut inspector")
        self.resize(1120, 760)
        layout = QVBoxLayout(self)
        title = QLabel("<h2>Synergy shortcut inspector</h2>")
        layout.addWidget(title)
        description = QLabel("Preview the configured PC → Mac path and every app branch. No keys are sent; the current Mac app is not queried.")
        description.setWordWrap(True)
        layout.addWidget(description)
        controls = QHBoxLayout()
        self.query = ShortcutInput()
        self.query.setAccessibleName("Shortcut search")
        self.query.setText(query)
        self.record = QPushButton("Capture chord")
        self.record.setCheckable(True)
        self.record.toggled.connect(self.query.capture)
        self.query.captureFinished.connect(lambda: self.record.setChecked(False))
        self.device = QComboBox()
        self.device.addItems(["Keyboard", "Logitech G903"])
        self.device.setAccessibleName("Input device")
        self.reload = QPushButton("Refresh sources")
        self.reload.clicked.connect(self.load)
        for widget in [self.query, self.record, self.device, self.reload]:
            controls.addWidget(widget, 1 if widget is self.query else 0)
        layout.addLayout(controls)
        hint = QLabel("Thumb = Ctrl · Pinky = Meta · Cmd/Command/Super = Meta · Use +, - or spaces. For Linux-reserved shortcuts, type their names.")
        hint.setWordWrap(True)
        layout.addWidget(hint)
        self.status = QLabel("Loading sources…")
        self.status.setWordWrap(True)
        layout.addWidget(self.status)
        split = QSplitter()
        self.results = QListWidget()
        self.results.setAccessibleName("Matching shortcuts")
        self.details = TraceView()
        self.details.setAccessibleName("Shortcut trace")
        self.details.setOpenLinks(False)
        self.details.anchorClicked.connect(QDesktopServices.openUrl)
        split.addWidget(self.results)
        split.addWidget(self.details)
        split.setSizes([340, 760])
        layout.addWidget(split, 1)
        footer = QLabel("Source preview, not a live delivery test. Capture sees events after Linux remapping and does not intercept desktop shortcuts.")
        footer.setWordWrap(True)
        layout.addWidget(footer)
        self.query.textChanged.connect(self.search)
        self.query.returnPressed.connect(lambda: self.results.setFocus())
        self.device.currentTextChanged.connect(self.search)
        self.results.currentItemChanged.connect(self.selection)
        if self.catalogs:
            self.search()
        else:
            self.load()

    def load(self):
        if self.loader and self.loader.isRunning():
            return
        self.reload.setEnabled(False)
        self.status.setText("Reading NixOS and chezmoi sources…")
        self.loader = SourceLoader(self)
        self.loader.loaded.connect(self.loaded)
        self.loader.failed.connect(self.failed)
        self.loader.finished.connect(lambda: self.reload.setEnabled(True))
        self.loader.start()

    def loaded(self, value):
        _, self.catalogs = value
        self.search()

    def failed(self, error):
        # Do not leave an earlier result looking current after a failed refresh.
        self.catalogs = {}
        self.results.clear()
        self.details.clear()
        self.status.setText("Cannot read mappings: " + error)

    def search(self):
        catalog = self.catalogs.get(self.device.currentText())
        if not catalog:
            return
        rows = catalog.search(self.query.text())
        self.results.clear()
        for row in rows:
            item = QListWidgetItem(row.input + "\n" + (row.rule or ""))
            item.setData(Qt.ItemDataRole.UserRole, row)
            self.results.addItem(item)
        warning = " · " + " ".join(catalog.sources.warnings) if catalog.sources.warnings else ""
        self.status.setText(f"{len(rows)} {'result' if len(rows) == 1 else 'results'} · {catalog.sources.origin}" + warning)
        if rows:
            self.results.setCurrentRow(0)
        else:
            self.details.setPlainText("No matches. Try a shortcut such as thumb+l or an action such as window focus.")

    def selection(self, item, _previous=None):
        if item:
            self.details.show_trace(item.data(Qt.ItemDataRole.UserRole), self.query.text())

    def closeEvent(self, event):
        # Closing never cancels or kills a worker mid-read; it can finish hidden.
        self.record.setChecked(False)
        if self.loader and self.loader.isRunning():
            self.hide()
            self.loader.finished.connect(self.finish_close)
            event.ignore()
        else:
            super().closeEvent(event)

    def finish_close(self):
        self.close()
        app = QApplication.instance()
        # The first close hid the window before its worker finished, so Qt's
        # lastWindowClosed signal may not fire on the second close.
        if app.quitOnLastWindowClosed() and not any(w.isVisible() for w in app.topLevelWidgets()):
            app.quit()

    def wait_for_loader(self):
        # Application shutdown can bypass closeEvent, for example on SIGTERM
        # in the tray. Let its bounded, read-only Nix evaluation finish first.
        if self.loader and self.loader.isRunning():
            self.loader.wait()


def main(query=""):
    app = QApplication(sys.argv[:1])
    app.setApplicationName("synergy-keys-inspector")
    window = InspectorWindow(query)
    window.show()
    return app.exec()
