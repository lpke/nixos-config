# Synergy keyboard mappings

`synergy-keys` reads the local Synergy log and selects xremap's `local` or `mac`
mode. Hammerspoon on the Mac resolves foreground app context when each reserved
shortcut arrives. This package contains no SSH connection, observer, host,
remote app list, or fallback backend.

Commands: `synergy-keys status`, `synergy-keys refresh`, `synergy-keys logs`.
The tray starts the screen watcher while sharing runs and restores Linux
mappings when sharing stops. Log rotation and truncation preserve screen state.
Restarting xremap reasserts the current screen's mode.

The canonical shortcut protocol lives in dotfiles
`dot_hammerspoon/synergy-keymap.json`. Its mirror is
`user/xremap/synergy-keymap.json`; keep both byte-identical. It covers all 148
app-dependent chords, including Shift/Alt/Super variants. Common launch, close,
focus, growth, scroll, mouse gestures, and internal mode keys live separately in
`user/xremap/mac-common.nix`.

Never allocate Ctrl+Alt+F1–F12 tokens without Shift. Linux intercepts them as
virtual console switches even with Meta held. Avoid Ctrl+Shift+Meta+arrows,
which KDE uses to move windows between desktops. Hyper+F9–F16 and Hyper+Y,
M/N, D/Escape, H/J/K/L are already reserved for other Mac actions.

The Mac receiver creates fresh native key events and complete target taps.
Do not set explicit Unicode text on Command events: macOS then bypasses native
editing shortcuts such as Select All. Right Command remains explicit for
terminal clipboard and the Ctrl+Shift+Down relay.

Run `PYTHONPATH=pkgs/synergy-keys python3 -B -m unittest discover -s pkgs/synergy-keys -v`.
Tests cover intended app mappings, transport collisions, mirrored manifests,
screen transitions, log rotation/truncation, missing-log recovery, and mode
application failures. Dotfiles contains the desktop-control tests. Live checks
use disposable browser and terminal windows and verify actual editing, terminal
bytes, and window geometry through Synergy.
