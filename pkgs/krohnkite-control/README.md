# Krohnkite controls

`krohnkite reload` rereads the applied settings without replacing the live tiler.
It keeps tile order, layout proportions, desktop layout choices and manual
floating decisions. App-class/title rules affect newly opened windows. Applied
KWin settings also refresh automatically after a KWin reconfigure. The activation
hook sends it after Plasma Manager writes settings during rebuilds.

Run `krohnkite restart` once to load this support into an older running session,
or after changing the tiler code. It replaces only Krohnkite, waits for shutdown,
copies the entire installed bundle to fresh URLs to bypass Qt's cache, and waits
for the initialized replacement to acknowledge it. It resets runtime layout
choices; use `reload` for settings. A failed replacement attempts to restore the
last acknowledged bundle, when available. The first replacement has no saved
bundle to recover. Neither command restarts the Wayland compositor.

Settings that change desktop/activity layout identity or dock structure require
an explicit script restart. Changes to layout defaults affect new layout
instances; existing instances keep their manual adjustments. A full compositor
binary update still requires a new session. These controls do not recover an
unidentified second tiler loaded independently under another name.

The lifecycle patch is `patches/krohnkite-live-reload.patch`. It disconnects native
and shortcut signals and cancels deferred work when QML unloads. Upstream's newer
[runtime cleanup](https://codeberg.org/anametologin/Krohnkite/src/branch/master/src/driver/kwindriver.ts)
uses the same explicit ownership; this backport keeps the installed layout engine.

Checks: build this package for its fake-D-Bus tests; run
`node --test patches/krohnkite-{focus,reload}.test.cjs` with `KROHNKITE_SCRIPT`
pointing to the built script. Set `KROHNKITE_CONTROL` to the built command when
running `patches/krohnkite-focus-headless.py --package <built-krohnkite>` for
private-compositor reload, floating and restart checks.
