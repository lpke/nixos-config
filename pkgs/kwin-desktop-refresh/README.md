# Steady desktop refresh

Keeps the Alienware AW3926QW presenting frames at its configured refresh rate
while Adaptive Sync stays on **Always**. When WoW has focus on that monitor,
the extra redraws stop so the game can use variable refresh. Alt-tabbing back
resumes desktop redraws without changing the monitor's VRR setting.

## Enable

1. Rebuild this NixOS configuration with `bnix`.
2. Log out and back in to make the native plugin available to KWin.
3. In KDE Display Configuration, select the Alienware, choose **5120×2160 at
   165 Hz**, and set **Adaptive Sync → Always**.
4. Check the monitor's refresh-rate counter on an idle desktop, then focus WoW
   and alt-tab back. The desktop should stay near 165 Hz; WoW can vary its rate.

The effect is enabled declaratively in `user/plasma/apps/kwin.nix`. That file
also contains its settings under `Effect-desktoprefresh`:

- `Output`: exact monitor model or connector name. The default `AW3926QW`
  keeps working if the monitor moves to another port.
- `ExcludedClasses`: comma-separated window classes/app IDs, case-insensitive.
- `ExcludedTitles`: comma-separated complete window titles, case-insensitive.

Both exclusion lists support `*` and `?` wildcards. WoW's title is included
because Steam assigns WoW and Battle.net the same `steam_app_3407247691` class.
Only a focused excluded window on the target monitor pauses the effect.
Add other games to these lists and rebuild to persist changes.

## Inspect or disable

Show the selected output, whether redraws are running, and their cumulative count:

```sh
busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects debug ss desktoprefresh ''
```

Run that twice a few seconds apart. `requestedFrames` should increase on the
desktop and stop while an excluded app has focus. These are redraw requests,
not a measurement of the monitor's actual refresh rate.

Disable immediately without restarting the session:

```sh
busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects unloadEffect s desktoprefresh
```

To disable persistently, set `Plugins.desktoprefreshEnabled = false` in
`user/plasma/apps/kwin.nix` and rebuild. Set Adaptive Sync back to **Never** if
you want to stop desktop VRR flicker after unloading the effect.

## How it works and limits

After KWin paints the target output, the effect damages one logical pixel to
request another frame. It changes no pixel colors and draws no overlay. KWin's
own presentation scheduler paces the requests at the configured display rate.
The effect also requests a frame directly from the output's render loop. This
bypasses KWin's 33 ms delay for effect redraws when an animated window controls
VRR, while retaining its normal limit on frames in flight. Without that request,
scrolling or window animations could slow the desktop redraws and cause flicker.
No synthetic input is sent, and the effect never changes VRR, HDR, resolution,
refresh rate, or the FPS caps of any app.

Redraws stop when the output is absent, disabled, asleep, not set to Always,
or the session is locked. Focus changes update immediately; a 250 ms policy
check also handles changes to window titles, classes and output placement.

This uses extra CPU/GPU work compared with an idle desktop. While active, it
blocks direct scanout so fullscreen applications cannot bypass the redraw loop;
that restriction disappears while the effect is paused for a game. KWin's
effect interface makes that restriction global, including other monitors.
Rendering stalls and game/desktop frame-rate transitions may still cause OLED
flicker. This is a redraw workaround, not a hardware guarantee of exactly 165 Hz.

The native plugin builds against the KWin version in this flake and must be
rebuilt with KWin upgrades. `ctest` checks app matching and pause conditions as
part of the Nix package build, plus the real KWin scheduler's handling of delayed
VRR requests and frames in flight.
