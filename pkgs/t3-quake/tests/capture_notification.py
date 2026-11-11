"""Capture the actual notification popup, including unmanaged X11 popups."""
import ctypes as C
import os
import sys
import time
from PyQt6.QtGui import QGuiApplication

if os.environ.get('DISPLAY') != ':99' or os.environ.get('XDG_RUNTIME_DIR') != '/lab/runtime':
    raise SystemExit('Only the private test display may be captured')
app = QGuiApplication(sys.argv)
x = C.CDLL('libX11.so.6')
window = C.c_ulong
x.XOpenDisplay.argtypes = [C.c_char_p]
x.XOpenDisplay.restype = C.c_void_p
x.XDefaultRootWindow.argtypes = [C.c_void_p]
x.XDefaultRootWindow.restype = window
x.XQueryTree.argtypes = [C.c_void_p, window, C.POINTER(window), C.POINTER(window),
                        C.POINTER(C.POINTER(window)), C.POINTER(C.c_uint)]
x.XFetchName.argtypes = [C.c_void_p, window, C.POINTER(C.c_char_p)]
x.XFree.argtypes = [C.c_void_p]
x.XCloseDisplay.argtypes = [C.c_void_p]
x.XGetGeometry.argtypes = [C.c_void_p, window, C.POINTER(window), C.POINTER(C.c_int),
    C.POINTER(C.c_int), C.POINTER(C.c_uint), C.POINTER(C.c_uint), C.POINTER(C.c_uint), C.POINTER(C.c_uint)]
display = x.XOpenDisplay(b':99')
if not display:
    raise SystemExit('Private X server unavailable')
try:
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        root, parent, children, count = window(), window(), C.POINTER(window)(), C.c_uint()
        x.XQueryTree(display, x.XDefaultRootWindow(display), C.byref(root), C.byref(parent),
                     C.byref(children), C.byref(count))
        try:
            for index in range(count.value):
                name = C.c_char_p()
                x.XFetchName(display, children[index], C.byref(name))
                title = name.value.decode(errors='replace') if name.value else ''
                if name:
                    x.XFree(name)
                geometry_root, left, top, width, height, border, depth = window(), C.c_int(), C.c_int(), C.c_uint(), C.c_uint(), C.c_uint(), C.c_uint()
                x.XGetGeometry(display, children[index], C.byref(geometry_root), C.byref(left), C.byref(top),
                    C.byref(width), C.byref(height), C.byref(border), C.byref(depth))
                screen = app.primaryScreen().geometry()
                # Notification popups may have no WM_NAME and be unmanaged. This
                # private desktop has exactly one notification; its right-bottom
                # surface is distinct from the full-width panel and main windows.
                popup = (250 <= width.value <= 800 and 60 <= height.value <= 400 and
                    left.value > screen.width() - 900 and top.value > screen.height() - 500)
                if 'T3 quake' in title or popup:
                    image = app.primaryScreen().grabWindow(int(children[index]))
                    if not image.isNull() and image.save('/lab/notification-detail.png'):
                        raise SystemExit(0)
        finally:
            if children:
                x.XFree(children)
        time.sleep(.05)
    raise SystemExit('Native error popup was not found on the private display')
finally:
    x.XCloseDisplay(display)
