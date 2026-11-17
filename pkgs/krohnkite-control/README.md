# Krohnkite controls

Launch **Krohnkite** from the app launcher or run `krohnkite` to start tiling and
its tray. `start` restores both, `stop` keeps the controls available, and `quit`
stops tiling and closes the tray. Both start at desktop login. `status` reports
actual KWin state; `help` opens the short guide in Neovim in a new Alacritty window.

The tray service owns startup and unconditional stop cleanup, including after
SIGKILL. Its icon stays white in either state and uses the shared fractional-scale
SVG renderer. Runtime controls own KWin's enable flag so Stop survives KWin
reconfiguration. Restarting or updating the tray starts tiling again.
Stopping restores borders and stacking flags owned by tiling, leaving geometry
free to move. T3 Quake refreshes tiler state before borrowing a window.

`reload` preserves tile order, layout proportions and manual floating choices;
class/title rules affect new windows. Desktop/activity identity and dock
structure changes need `restart`. Code restart uses fresh bundle URLs, confirms
shutdown/readiness and can recover a previously acknowledged bundle. It resets
runtime layout choices; the first replacement has no saved recovery bundle.

`recover` clears older orphaned callbacks by resetting all KWin scripts while
keeping apps and the compositor alive. The native recovery plugin explicitly
loads the installed tiler and refreshes inherited Nix data paths. Compositor
binary updates still need a new session.

Build this package for isolated Qt and fake-D-Bus tests. The compiled tiler tests
use `KROHNKITE_SCRIPT` with `patches/krohnkite-{focus,reload}.test.cjs`.
`patches/krohnkite-focus-headless.py --package <tiler>` uses a private compositor.
Set `KROHNKITE_CONTROL` to the built CLI and `KROHNKITE_SERVICE_CHECK=1` to add
resource-limited temporary-service stop, relaunch and SIGKILL checks; all window
operations and configuration remain private. The tray's stop hook also runs when
it is killed, so launch the desktop app to restore it.
