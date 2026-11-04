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

Previously focus used KWin's committed window geometry while swaps used
Krohnkite's layout geometry. Those can differ during client resize/configure
updates. The intermittent Alacritty/Helium reversal was not reproduced during
ordinary opening in the isolated compositor. The change removes that disagreement
for tiled neighbors; its regression test also models unsettled client geometry.

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

`bnix` installs the package and saved shortcut assignments. Leave the existing
compositor and its shortcuts loaded while the user is working. The change takes
effect at the next login.
