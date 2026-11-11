# T3 quake

<kbd>Alt+`</kbd> or `t3-quake` borrows T3 Code’s existing window as a top-centred
drop-down at 60% of the focused app’s monitor. T3 opens normally by default;
Yakuake keeps Print.

Press the hotkey again, run `t3-quake restore`, or focus another app to return
T3 without switching desktops. A real placeholder preserves its Krohnkite
slot; focus it to recall T3 there. T3’s own Quit still quits T3.

- `t3-quake status`: read status without starting a stopped helper.
- `t3-quake restart`: restore T3 and reload only the helper and quake script.
- `journalctl --user -u t3-quake`: helper diagnostics; compositor errors also
  appear in KWin’s journal.

The helper starts with T3’s window and exits when it closes. Failure restores
normal window use and shows a silent system notification with the restart
command. T3’s executable, launcher, backend and settings remain independent.

## Deployment

`user/t3-quake.nix` owns packaging, the shortcut and on-demand services.
`patches/krohnkite-t3-quake.patch` preserves tile and layout identity while
borrowing. Deploy both with the normal NixOS switch, then log in again.
Do not activate the controller against an older Krohnkite package.
The `t3-quake` development branch has **not** been activated on the live desktop.

## Tests

The package runs controller and bridge checks. `tests/tiling.test.cjs` runs
against the built patched script via `KROHNKITE_SCRIPT`, alongside
`patches/krohnkite-focus.test.cjs`.

`python3 pkgs/t3-quake/tests/run_lab.py --help` describes isolated acceptance.
Supply the built helper, patched tiler, an extracted T3 app and a fresh artifacts
directory. Use low CPU/I/O priority and restricted CPU affinity. The disposable
namespace has no live home, session sockets, network, GPU or audio devices.
Wayland checks include mixed-scale stacked outputs; `--desktop x11` uses
CPU OpenGL/Xvfb for screenshots and animation captures. Destructive failure
tests disable core dumps; host crash reporting may still need temporary muting.
Physical hotkey dispatch, the active GPU compositor and actual games remain
live acceptance checks.
