# Monitor control (Linux)

A native Qt tray and searchable Home Manager application. The four top-level
entries are **Black out**, **Black out hotkey monitor**, **Label monitors**, and
**Quit**. Each submenu starts with **All monitors**, followed by connected named
outputs. Left or right click opens the tray menu. Disabled connected outputs appear but cannot be blacked out. Labels use
exactly the menu's monitor name.

Individual blackout entries toggle independently, with the same 250 ms
smoothstep fade in both directions as the Mac app. An interrupted fade reverses
from its current opacity, with duration scaled by the remaining distance.
**All monitors** fills any
remaining active outputs when none or some are covered; it restores all when all
are covered. Its checkmark means every eligible output is covered. The hotkey
selection defaults to All, persists in the user's configuration, and can target
a specific connector. An unavailable saved target reports an error rather than
silently switching monitors.

Labels have white text and a five-pixel white border on black, centered in each
output. They hold for five seconds, fade for 250 ms, and dispose the temporary
surface/process. A label over an existing blackout shares that surface, and
leaves its cover unchanged. Labels do not accept input or request activation;
blackout covers consume pointer clicks on hidden content without grabbing the
keyboard or pointer. Hardware brightness, display configuration and focus stay
untouched.

`monitor-control` opens/reopens the tray without a foreground window. It supports
`toggle [all|OUTPUT]`, `select all|OUTPUT`, `label`, `restore`, `status`, and `quit`;
see `monitor-control --help`. Omitted toggle targets use the saved hotkey
selection. `display-brightness-toggle` is a compatibility wrapper around that
same toggle. Hyper+D uses the Monitor control desktop action and stable managed
command link, so it shares the tray's selection after a manual Home Manager
activation and across package rebuilds.

## Ownership and lifecycle

`monitor-control.service` follows the graphical session, using the same startup
pattern as the existing T3 tray. Quit exits successfully, so `Restart=on-failure`
does not restart it. Search, the CLI or the hotkey can start it again.

One lifetime advisory lock protects a user-only local socket. Every menu/CLI
request runs in the controller's Qt event loop; callers never infer state from
PID or marker files. The lock remains valid across stale socket cleanup and
concurrent starts. Persistent settings are atomically replaced; blackout state
is deliberately session-only. Socket frames, idle clients and subprocess startup
and shutdown are bounded. Each visible output gets one supervised QML worker;
pipe EOF removes its surface if the controller dies. systemd also owns the whole
process group. Worker failure clears the corresponding menu state and reports
the error, without changing other outputs.

`surface.py` exposes the real `QScreen` to layer-shell. QML's `Window.screen`
wrapper is not a substitute for that native object. Binding the layer-shell
surface explicitly, before mapping it, avoids relying on virtual coordinates to
choose an output at fractional scale or an offset origin. Output removal closes
the worker rather than moving a cover to another monitor. Qt supplies active
outputs and model names; DRM EDID also names connected disabled monitors. DRM
names are ignored when they do not match the compositor (e.g. nested KWin).
Workers use Qt Quick's software renderer for these simple static surfaces, so
blackout and labels do not require a working application EGL context.

## Deployment (parent/owner only)

This implementation does not activate configuration or change live services.
Build the integrated Home Manager activation package, then activate it using the
normal manual Home Manager procedure. The module provides explicit managed
`~/.local/bin/{monitor-control,display-brightness-toggle}` links and a managed
`~/.local/share/applications/monitor-control.desktop`; `useUserPackages=true`
otherwise leaves `/etc/profiles/per-user/luke` unchanged after manual activation.
This Home Manager version packages `xdg.desktopEntries` in `home.path`, so the
module also links the generated app entry into the home application directory.
The app's `toggle-blackout` action owns Hyper+D; the old Plasma Manager action
is unassigned. KGlobalAccel cached that old action's primary-only command even
after its desktop file and application cache were updated. Using a distinct
action under Monitor control avoids that stale owner. Its Exec uses the managed
home command link so future rebuilds do not leave a cached package path.
Refresh KDE's application
cache if the newly installed entry is not yet indexed (`kbuildsycoca6 --noincremental`).
The user service can then be started with `systemctl --user start monitor-control`.
For a current-session shortcut migration, update just these two KGlobalAccel
registrations; do not restart KWin. Saved settings supply them at the next login.
No full-system switch is needed for these user paths or this shortcut. The next
system switch installs the system-level command and compatibility wrapper too.

The legacy transient `display-blackout.service` is a separate owner. Read its
status before migration. If it is active, explicitly restore/remove that old
cover through its old owner before starting new covers; do not silently kill it
or assume its brightness was 100%. The retired helper forced 0/100 brightness
rather than restoring a saved value. This app never takes over or changes that
brightness. At implementation inspection the legacy unit was inactive/dead with
no unit file path; the live outputs reported brightness 1. No legacy service was
stopped or brightness changed by this work.

## Validation

The Nix derivation runs the focused state, menu, output-name and socket tests
with offscreen Qt. They cover All none/partial/all behavior, independent covers,
saved and missing targets, corrupt settings, checkmarks, exclusive selection,
fragmented/invalid/oversized IPC messages, and nested-output inventory isolation.

`tests/wayland_acceptance.py` creates its own temporary runtime/config/data/cache,
private DBus daemon with no service activation, and headless KWin virtual outputs.
It removes the inherited desktop socket/display and never injects input. It
terminates every compositor, controller and private bus it starts, including on
failure. Dependencies can be located without scanning the store:

```sh
nix eval --impure --json --expr '
  let f = builtins.getFlake ("path:" + toString ./.);
      p = f.nixosConfigurations.lpnix.pkgs;
  in { python = toString (p.python3.withPackages (ps: [ ps.pyqt6 ]));
       kwin = toString p.kdePackages.kwin;
       layer = toString p.kdePackages.layer-shell-qt; }'
```

From the repository root, use those paths and the built package:

```sh
PYTHONPATH=pkgs/monitor-control:pkgs/tray-support "$python/bin/python" -B \
  pkgs/monitor-control/tests/wayland_acceptance.py \
  --kwin "$kwin/bin/kwin_wayland" \
  --daemon "$package/bin/monitor-control-daemon" \
  --layer-import "$layer/lib/qt-6/qml" --artifacts /tmp/monitor-control-review \
  --hotkey-desktop ~/.local/share/applications/monitor-control.desktop
```

Acceptance verifies actual layer-shell rendering on each named output at scale
1 and 1.5 with offset origins, multiple covers, All semantics, label text/border/
centering/timing, retained covers, concurrent IPC requests, Quit/reopen/persistence
and an unavailable saved target. The optional desktop argument executes the
installed hotkey action's exact command against the private controller, checking
both partial-to-all and all-to-none without invoking the active desktop shortcut.
Artifacts include actual production-QML PNGs,
layout JSON, protocol/controller logs and the result report. PNGs use
`QQuickWindow.grabWindow()` on that private compositor: they are rendered Qt Quick
surfaces, not full-desktop screenshots. This host cannot initialize EGL for the
isolated KWin backend, so the harness uses QPainter.

KWin 6.6 rejects negative positions for enabled outputs and KScreen normalizes
requested negative origins. The harness therefore also maps the production QML
surface with a negative initial Qt position while keeping its explicit native
output binding, and checks its actual named output and rendering. This does not
claim an enabled physical KWin output with a negative origin was tested.
