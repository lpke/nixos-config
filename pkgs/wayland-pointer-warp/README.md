# Wayland pointer restoration

Xwayland can release a hidden pointer while its latest position hint is still
behind a GPU-fenced surface commit. X11 applications then report their requested
coordinates while the visible desktop pointer restores an older position.

The Xwayland patch binds the optional standard `wp_pointer_warp_v1` protocol and
sends one direct restoration request when its existing warp emulator unlocks. It
uses the current callback position, the latest pointer-enter serial, the same
focused owning window and in-window bounds. Unsupported compositors keep native
behavior. Pointer locks, confinement and existing fallback hints remain upstream.

The KWin patch makes the existing protocol handler resolve its actual Xwayland
client's windows and convert surface scale before checking bounds and mapping the
point. Existing focus, serial and lock checks remain in place. It does not include
the broader pointer-constraint transaction backport.

There are no application names, device identifiers, GPU completion waits, frame
waits or sleeps. Xwayland's existing nonblocking cursor reveal timer remains
unchanged so X11 warp/show requests can arrive together. Removing that policy is
unnecessary for this correction and could reveal the old cursor before a warp.

`system/desktop/pointer-warp.nix` applies both packages and preserves NixOS's
configured Xwayland font directory. The version assertions require reviewing or
removing these patches on package upgrades. The existing Nixpkgs patches remain.

KWin builds and runs its pointer-constraint integration suite, extended with
real protocol scaling/serial/bounds checks and an X11-window dispatch regression.
Xwayland end-to-end testing belongs in an isolated compositor. A compiled package
or a private test plugin alone does not establish desktop correctness or latency.
The exact packages passed isolated native acceptance and software timing review
with Power Beta 4.7.3 and its 4.7.2 baseline. Astra xhigh approved that tested
stack. This does not establish physical input-to-photon latency or the owner
session's behavior before it loads the new packages.
The focused KWin suite passes all 11 cases, including native protocol scaling and
an actual X11-window dispatch regression.

Protocol reference: https://wayland.app/protocols/pointer-warp-v1
Related upstream race: https://bugs.kde.org/show_bug.cgi?id=520910

Native checks covered static GUI restoration under GPU load, post-visible motion,
fullscreen and fractional scale, rapid inventory gestures, static X11 confinement,
hidden grabs, window destruction and actual XKB Mouse Keys. Timing used both mouse
helpers at 30/60/160 FPS and VSync, with a varied-interval 160 FPS repeat. No game
presentation waits were added. Existing desktop sessions keep their loaded binaries;
logout/login loads the correction after activation.
