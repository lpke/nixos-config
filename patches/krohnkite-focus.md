# Directional focus

Meta+H/J/K/L belongs to the independent `directional-focus` KWin script. On each
press it checks whether Krohnkite is loaded. If so, it invokes the corresponding
Krohnkite focus action. Otherwise it calls KWin's native directional-focus slot.
Disabling and re-enabling Krohnkite does not remove the shortcut owner.

Within the patched Krohnkite driver, a tiled window with a neighbor in that
direction uses the same layout geometry and neighbor selection as swaps. The
driver falls back to KWin when there is no tiled neighbor, including wraparound,
floating or unmanaged windows, and navigation to another output. Meta+arrow
swaps are unchanged.

The reproduced failure is in KWin 6.6.5's native directional search. It considers
deleted windows retained in the stacking order, then `activateWindow()` rejects
the selected deleted window. The observed Prism Launcher entry was an X11 window
that still reported itself as wanting input after closing. An unmapped Wayland
toplevel no longer wants tab focus, so two live Wayland apps alone did not
reproduce this. On the affected desktop the closed Prism Launcher
window scored 1189 for focus right, ahead of the live Helium window at 2048.
Meta+L consequently did nothing; Meta+H wrapped to Helium on the right. Both
OS key events through ydotool and direct native action dispatch reproduced this.

The earlier theory about unsettled client geometry was not the cause of this
captured failure. The tiled workaround already skips deleted windows through
Krohnkite's visibility filter. It was activated and tested successfully against
the affected desktop without moving windows or reloading Krohnkite.

`kwin-skip-deleted-focus.patch` fixes the native search itself by excluding
`isDeleted()` candidates. It has no application-specific rules and preserves
the existing scoring, desktop/activity filtering and wraparound. The KWin package
builds and runs `testActivation`, including a retained closed X11 window between
live Wayland windows in all four directions and wraparound, alongside the
pointer-constraint suite.

The patch uses existing stale-driver and re-entry guards. It calls native KWin
slots directly, so falling back cannot recursively dispatch the same shortcut.
The native and Krohnkite focus shortcut assignments are cleared to give each
chord one owner. Krohnkite's actions remain callable through KGlobalAccel without
assigned keys. The independent script checks loaded state on every press, so it
does not retain a stale enabled flag or require polling. Keep `Directional window
focus` enabled in KWin Scripts when disabling Krohnkite.

Build and check the exact patched package from the repository root:

```sh
krohnkite_package=$(nix build --no-link --print-out-paths --impure --expr '
  let f = builtins.getFlake "/home/luke/.config/nixos";
  in builtins.head (builtins.filter (p: (p.pname or "") == "krohnkite")
    f.nixosConfigurations.lpnix.config.environment.systemPackages)')
KROHNKITE_SCRIPT="$krohnkite_package/share/kwin/scripts/krohnkite/contents/code/script.js" \
  node --test patches/krohnkite-focus.test.cjs
node --test user/plasma/directional-focus.test.cjs
python3 patches/krohnkite-focus-headless.py --package "$krohnkite_package"
```

The native checks start a separate KWin with two virtual outputs, software
rendering, private XDG directories, a private D-Bus without service activation,
and a temporary browser profile. They emit the script's shortcut signals inside
that compositor. They do not inject keyboard or mouse events. They check focus
in both directions, both wraparound directions, swaps, floating windows and
navigation between outputs. It then dispatches the registered shortcuts over
the private D-Bus, disables and re-enables Krohnkite twice, checks native focus in
all four directions while disabled, and checks that shortcut ownership survives.
The test terminates its own processes and removes its temporary files.

`bnix` installs the package and saved shortcut assignments. Loading the independent
router is sufficient to activate the tiled workaround in an existing session;
clear the old native action bindings first. Do that only when session interaction
is authorized. The native KWin binary fix takes effect at the next login; do not
restart a Wayland compositor with applications open just to load it.
