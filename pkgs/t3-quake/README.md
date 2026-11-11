# T3 Quake

**T3 Code** opens without drop-down controls. **T3 Quake** opens the same app
with those controls enabled, initially as a normal window. Close one before
opening the other; mixing modes shows a system notification.

<kbd>Alt+`</kbd> or `t3-quake` borrows the existing T3 Quake window onto the
focused app's monitor. A focusable placeholder preserves its Krohnkite tile.
Press again or focus another app to return it without following its home desktop;
focus the placeholder to recall it there. Yakuake keeps Print.

- `t3-quake launch`: open T3 Quake without summoning the drop-down.
- `t3-quake restore`: return the borrowed window.
- `t3-quake status`: inspect without starting the helper.
- `t3-quake restart`: recover and reload only drop-down handling.
- `journalctl --user -u t3-quake`: helper diagnostics.

Chezmoi's T3 launcher arbitrates modes and owns helper lifetime, including native
updater relaunches. Closing T3 Quake stops the helper. Helper failure leaves T3
usable and shows a silent notification with the restart command. NixOS owns
`user/t3-quake.nix`, the controller/effect, shortcut and tiler patch. Native T3
requires the public GLVND libraries in `programs.nix-ld` for hardware rendering.

The package checks controller and bridge behavior. `tests/tiling.test.cjs` and
`patches/krohnkite-focus.test.cjs` use the built tiler through `KROHNKITE_SCRIPT`.
Chezmoi's T3 tests cover native launch, mode exclusion and helper cleanup.
`tests/run_lab.py --help` describes isolated acceptance; live GPU, animation,
monitor scaling and shortcut checks need a separately authorized desktop test.
