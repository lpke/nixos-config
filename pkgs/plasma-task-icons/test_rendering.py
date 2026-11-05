"""Render the actual patched task icon with Kirigami and measure alignment."""

import os
from pathlib import Path
import re
import sys
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
from PyQt6.QtCore import QEventLoop, QTimer, QUrl
from PyQt6.QtGui import QColor, QGuiApplication
from PyQt6.QtQuick import QQuickView


source = Path(sys.argv.pop(1)).read_text()
imports = sys.argv.pop(1)
block = re.search(r"        Kirigami.Icon \{\n(.*?)\n        \}", source, re.S).group(1)
baseline = block[:block.index("            // Kirigami snaps")] + "            anchors.fill: parent\n" + block[block.index("            active: task.highlighted"):]
app = QGuiApplication.instance() or QGuiApplication([])
temporary = tempfile.TemporaryDirectory(prefix="task-icon-render-")
directory = Path(temporary.name)
icon = directory / "solid.svg"
icon.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="#ff0000"/></svg>')


def render(*, patched=True, popup=False, vertical=False, icons_only=True):
    body = block if patched else baseline
    body = body.replace("task.model.decoration", '"' + icon.as_uri() + '"')
    qml = '''import QtQuick
import org.kde.kirigami as Kirigami
Item {
 id: task
 width: 50; height: 25
 property bool inPopup: POPUP
 property bool highlighted: false
 property alias tasksRoot: taskRoot
 property var iconGeometry: [image.x,image.y,image.width,image.height]
 QtObject { id: taskRoot; property bool iconsOnly: ICONS; property bool vertical: VERTICAL }
 Item {
  x: 4; y: 3; width: 17; height: 19
  Kirigami.Icon { BODY }
 }
}'''
    replacements = {"POPUP": str(popup).lower(), "ICONS": str(icons_only).lower(), "VERTICAL": str(vertical).lower(), "BODY": body.replace("id: icon", "id: image")}
    qml = re.sub(r"\b(" + "|".join(replacements) + r")\b", lambda m: replacements[m.group()], qml)
    path = directory / f"{patched}-{popup}-{vertical}-{icons_only}.qml"
    path.write_text(qml)
    view = QQuickView()
    view.setColor(QColor(0, 0, 0, 0))
    view.engine().addImportPath(imports)
    view.setSource(QUrl.fromLocalFile(str(path)))
    if view.status() == QQuickView.Status.Error:
        raise AssertionError("\n".join(error.toString() for error in view.errors()))
    view.show()
    loop = QEventLoop()
    QTimer.singleShot(80, loop.quit)
    loop.exec()
    image = view.grabWindow()
    total = moment = 0
    for y in range(image.height()):
        for x in range(image.width()):
            alpha = image.pixelColor(x, y).alpha()
            total += alpha
            moment += (y + .5) * alpha
    if not total:
        raise AssertionError("Icon was not rendered")
    result = moment / total, 25 * view.devicePixelRatio() / 2, view.rootObject().property("iconGeometry").toVariant()
    view.close()
    view.deleteLater()
    return result


class TaskRenderingTests(unittest.TestCase):
    def test_compact_icon_center_is_within_half_a_physical_pixel(self):
        center, target, geometry = render()
        self.assertLessEqual(abs(center - target), .5)
        self.assertEqual(geometry[2], geometry[3])
        self.assertEqual(geometry[1] + geometry[3] / 2 + 3, 12.5)

    def test_fractional_scale_regression(self):
        if float(os.environ.get("QT_SCALE_FACTOR", "1")) != 1.25:
            self.skipTest("125% regression case")
        before, target, _ = render(patched=False)
        after, _, _ = render()
        self.assertGreater(abs(before - target), 1)
        self.assertLess(abs(after - target), abs(before - target))

    def test_other_task_geometries_remain_unchanged(self):
        for options in [{"popup": True}, {"vertical": True}, {"icons_only": False}]:
            with self.subTest(**options):
                self.assertEqual(render(**options), render(patched=False, **options))


if __name__ == "__main__":
    unittest.main()
