# Synergy Mac keys

The default `mac` backend reads Synergy's local screen-switch log and selects
xremap's local/remote modes. It never creates an SSH app observer. Hammerspoon
on the Mac reads foreground app context when an intent arrives.

`mac-keys status`, `start`, `retry`, `stop` and `logs` remain available. In the
new backend, start/retry refresh the controller; stop reports that SSH polling
is disabled and leaves screen detection active. Quitting Synergy restores
Linux mappings as before. The tray shows the active screen and local-context
backend, without an SSH retry menu.

The canonical intent protocol is dotfiles
`dot_hammerspoon/synergy-keymap.json`. Its Nix mirror is
`user/xremap/synergy-keymap.json`; keep both byte-identical. The protocol
preserves all 148 app-dependent chords from the previous mappings, including
Shift/Alt/Super variants. Tests compare every row with the preserved legacy
rules and check the existing common shortcuts/gestures remain unchanged.

Hammerspoon emits complete target taps for presses and repeats. Tokens can
share a transport keycode, so pairing each tap avoids ambiguous key releases.
The terminal clipboard and Hyper+Y paths explicitly retain right Command.
Native Karabiner, terminal app preferences, mouse profiles and Linux game
mappings remain separate and unchanged.

## Rollback

`user/xremap/backend.nix` selects `"mac"` or `"ssh"`. The previous xremap rules
remain in `mac-legacy.nix`; the SSH observer/service remain available but are
not started by the new backend.

A full rollback switches the PC to `"ssh"` and activates the matching Nix user
services/config. On the Mac, set the Hammerspoon setting
`synergy-keymap-backend` to `"ssh"` and reload while no relay key is held; init
then loads the preserved thumb+L receiver. Run `mac-keys start` to resume the
legacy SSH observer. Switch both ends together.

## Checks

Run `PYTHONPATH=pkgs/mac-keys python3 -B -m unittest discover -s pkgs/mac-keys -v`.
The desktop-control suite lives in dotfiles. Its Mac tests construct and
inspect real event objects without posting input. Keyboard/mouse behavior is
tested manually by the user.
