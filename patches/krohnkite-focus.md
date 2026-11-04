# Directional focus

Meta+H/J/K/L belongs to the patched Krohnkite driver. For a tiled window with
a neighbor in that direction, focus uses the same layout geometry and neighbor
selection as directional swaps. It falls back to KWin's corresponding native
action when there is no tiled neighbor, including wraparound, floating or
unmanaged windows, and navigation to another output. Meta+arrow swaps are unchanged.

Previously focus used KWin's committed window geometry while swaps used
Krohnkite's layout geometry. Those can differ during client resize/configure
updates. The intermittent Alacritty/Helium reversal was not reproduced during
ordinary opening in the isolated compositor. The change removes that disagreement
for tiled neighbors; its regression test also models unsettled client geometry.

The patch uses existing stale-driver and re-entry guards. It calls native KWin
slots directly, so falling back cannot recursively dispatch the same shortcut.
The four native shortcut assignments are cleared to give each chord one owner.

Build and check the exact patched package from the repository root:

```sh
krohnkite_package=$(nix build --no-link --print-out-paths --impure --expr '
  let f = builtins.getFlake "/home/luke/.config/nixos";
  in builtins.head (builtins.filter (p: (p.pname or "") == "krohnkite")
    f.nixosConfigurations.lpnix.config.environment.systemPackages)')
KROHNKITE_SCRIPT="$krohnkite_package/share/kwin/scripts/krohnkite/contents/code/script.js" \
  node --test patches/krohnkite-focus.test.cjs
python3 patches/krohnkite-focus-headless.py --package "$krohnkite_package"
```

The native checks start a separate KWin with two virtual outputs, software
rendering, private XDG directories, a private D-Bus without service activation,
and a temporary browser profile. They emit the script's shortcut signals inside
that compositor. They do not inject keyboard or mouse events. They check focus
in both directions, both wraparound directions, swaps, floating windows and
navigation between outputs. The test terminates its own processes and removes
its temporary files.

`bnix` installs the package and saved shortcut assignments. Leave the existing
compositor and its shortcuts loaded while the user is working. The change takes
effect at the next login.
