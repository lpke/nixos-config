# Compact task icons

At the 25px panel height, Plasma's icons-only task manager gives its icon a
non-square viewport. Kirigami centers the smaller painted icon inside that
viewport and rounds its position. At fractional display scale, that rounding can
shift the painted icon down. An offscreen reproduction at 125% scale shows the
old solid test icon more than one physical pixel below the panel center.

The patch gives compact horizontal icons-only tasks a canonical square icon
viewport centered with explicit fractional coordinates. This avoids the extra
internal positioning step. Popup entries, vertical task managers and the ordinary
labeled task manager retain upstream geometry. Panel height, indicator artwork
and the adjacent Window Title/Global Menu text remain unchanged.

`system/desktop/task-icons.nix` applies the patch to `kdePackages.plasma-desktop`.
After patching, the package renders the actual patched Kirigami.Icon block in an
offscreen Qt Quick view at 100%, 125% and 200%. Tests measure its rendered alpha
center, reproduce the old offset, and check unchanged geometry outside the
compact icons-only case.
The test environment declares its own font configuration, writable cache/runtime
directories and Qt SVG plugins. Kirigami's QML import uses its `unwrapped` output;
the default Nixpkgs wrapper only propagates dependencies and contains no QML.

With PyQt6 available, run:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR=1.25 \
  python3 -B pkgs/plasma-task-icons/test_rendering.py /path/to/patched/Task.qml /path/to/kirigami/lib/qt-6/qml
```

The applet QML is compiled into a Plasma plugin. The existing shell can retain
that loaded plugin after installation. Restarting only `plasma-plasmashell.service`
loads it without restarting KWin, closing applications or logging out.
