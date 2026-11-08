# T3 status tray

Home Manager's `user/t3-tray.nix` starts one `t3-tray.service` at desktop login.
Its StatusNotifier id is `T3`. The service is independent of the connections and
Git review launcher, so closing its UI never pauses them.

The solid upper-left quarter reports Tailscale, the solid lower-left quarter
reports the Git review launcher, and the dotted right half reports SSH. Each
part turns aqua or red independently using that helper's JSON status. The T3
glyph is the original vector outline under `LICENSE-T3`. Eight icon states are
rendered once and cached. The icon is republished only when those health values
change, rather than at every poll.

Each transport has a submenu with Start, Pause, Show logs and Help. Help renders
the transport's help file and opens it in Neovim in a new Alacritty window,
using the user's `nvim` from PATH (Bob-managed on this machine). Show logs opens
Alacritty and keeps the window open after the command exits. Both actions pass
an explicit command, bypassing Alacritty's normal shell/tmux startup.

Git review has its own submenu with status, Start, Pause and Help. It calls the
installed `git-review-launcher` from PATH; the dotfiles source checkout is not
needed at runtime. Chezmoi owns that helper, its socket/worker and command help.
Ready means its listener can accept clicks, including while the worker has
exited after an idle period. Pause closes the listener without closing existing
review windows. A missing/old helper or missing dependencies affect only this
quarter and submenu; unavailable helpers disable Start. Status checks have a
12-second deadline. Installing or applying dotfiles is a separate operation.

Polls use separate asynchronous child processes, so an offline route cannot hold
up the other route or menu. Shutdown stops only child checks/commands before Qt teardown.
Global Quit tray exits the UI without changing either transport. `t3-tray show`
restores it; `t3-tray quit` hides it. Starting either helper also restores the tray.

The SSH target stays on demand, with its existing first-T3-launch startup marker.
Tailscale's main daemon still starts at boot and remembers the advertised route.
Each helper's Quit command now stops only its own transport, leaving the shared
tray available for the other transport. Transport credentials and T3 route order
remain outside the tray.

`pkgs/tray-support/tray_icon.py` keeps the original SVG in a content-addressed
cache under `$XDG_CACHE_HOME/tray-icons` and supplies its absolute filename as
`QIcon.name()`. KDE publishes that filename as StatusNotifierItem `IconName`,
letting Plasma render the SVG at the panel's own screen scale. The native menu retains the full
Tailscale · solid upper left, Git review · solid lower left and SSH · dotted right
labels. Three nonbreaking spaces
reserve a font-scaled right gutter before each submenu arrow. This survives
D-Bus menu import, unlike a producer-side widget stylesheet, and affects only
these submenu labels.

This avoids KDE's raster-export path, which calls `QIcon.pixmap(size)` using the
application's default pixel ratio. On this mixed-DPI desktop that doubled even
explicit intermediate sizes, leaving the 125% panel to resample them. The icon
engine still provides vector rendering and exact-size fallbacks for Qt consumers.
Both T3 and Synergy use the same loader. Unchanged status combinations do not republish.

KDE source: [`KStatusNotifierItemPrivate::iconToVector`](https://github.com/KDE/kstatusnotifieritem/blob/master/src/kstatusnotifieritem.cpp).

Run the Qt and tray CLI tests with PyQt6 available:

```sh
python3 -B pkgs/t3-tray/test_trays.py
```

The runner creates an isolated D-Bus session and uses the offscreen platform.
It tests all eight independent icon states, exact physical sizes, separate menu
commands and polling slots, malformed/error responses, no duplicate icon exports,
UI-only Quit, missing/old/timed-out review helpers and teardown of pending checks. Runtime controller tests remain in
each transport package. Live integration should verify the exported IconPixmap
sizes, menu/status and tray-only quit/show while preserving any SSH master/tunnel.

The real SNI export check needs the installed KDE platform-theme plugin, PyQt6,
`busctl` and `dbus-run-session`:

```sh
python3 -B pkgs/tray-support/test_sni.py
```

It starts a temporary watcher and tray on an isolated bus at 125% and 200% scale,
and asserts that the exported `IconName` is the actual source SVG. No production
tray, connection service or global D-Bus object is changed.
