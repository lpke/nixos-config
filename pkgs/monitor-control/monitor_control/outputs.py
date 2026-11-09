"""Use Qt's actual Wayland outputs; DRM adds connected but disabled monitors."""

from pathlib import Path

from .state import Output


def edid_name(data):
    if len(data) < 128 or data[:8] != b"\x00\xff\xff\xff\xff\xff\xff\x00":
        return ""
    for offset in (54, 72, 90, 108):
        descriptor = data[offset:offset + 18]
        if descriptor[:5] == b"\x00\x00\x00\xfc\x00":
            return descriptor[5:18].decode("ascii", errors="replace").strip(" \n\x00")
    return ""


def connected_outputs(app, drm=Path("/sys/class/drm")):
    screens = {screen.name(): screen for screen in app.screens()
               if screen.name() and screen.geometry().width() > 0}
    names = {}
    for connector in drm.glob("card*-*"):
        try:
            if (connector / "status").read_text().strip() != "connected":
                continue
            name = connector.name.split("-", 1)[1]
            names[name] = ""
            try:
                names[name] = edid_name((connector / "edid").read_bytes())
            except OSError:
                pass
        except OSError:
            continue
    # A nested compositor must never inherit the host's physical DRM outputs.
    if not names.keys() & screens.keys():
        names.clear()
    for name, screen in screens.items():
        names[name] = screen.model().strip() or names.get(name, "")
    # An empty Qt placeholder is not an eligible physical output.
    return [Output(name, f"{model} ({name})" if model and model != name else name,
                   name in screens)
            for name, model in sorted(names.items())]
