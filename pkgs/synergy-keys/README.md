# Synergy keyboard mappings

`synergy-keys` reads the local Synergy log and selects xremap's `local` or `mac`
mode. Hammerspoon on the Mac resolves foreground app context when each reserved
shortcut arrives. The controller contains no SSH connection, observer, host,
remote app list, or fallback backend.

Commands: `synergy-keys status`, `synergy-keys refresh`, `synergy-keys logs`,
`synergy-keys help`, `synergy-keys inspect`, `synergy-keys pause`, `synergy-keys resume`, and
`synergy-keys synergy pause|resume|config`.

The single visible **Synergy** tray starts at desktop login and stays available
when sharing stops. Its original multicolor Synergy ring means the sharing core is running;
the white pointer means `synergy-keys` is enabled and its controller is healthy,
including while the cursor is on the PC. Each part independently turns red when
paused or unavailable. SVG geometry is rendered at exact physical icon sizes
through the shared `pkgs/tray-support` loader, including fractional display scales.
The ring matches T3's 13px radius and 2.6px stroke on a 32px canvas.

The menu pauses/resumes sharing and keyboard mappings independently, opens the
native Synergy configuration, and retains shortcut inspection, refresh, logs and
help. Show logs uses a held Alacritty window. Command help (`synergy-keys help`)
copies the short Markdown guide to `$XDG_CACHE_HOME/synergy-keys/help.md` (defaulting
to `~/.cache`) and opens it in Neovim in a new Alacritty window, using the user's
`nvim` from PATH. Both actions bypass Alacritty's normal shell/tmux startup;
`synergy-keys --help` still prints help in the current terminal.

Pausing `synergy-keys` stops its controller and restores Linux mappings;
resuming arms the next sharing session if sharing is currently stopped. Choices
persist in `~/.local/state/synergy-keys/controls.json`, respecting XDG overrides.
Refresh preserves an explicit keyboard pause. Pausing sharing does not change
the independent keyboard preference. After a restart, the tray reasserts a
saved sharing pause if Synergy starts its core automatically.

Sharing controls use the installed Synergy native tray's own Start/Stop D-Bus
menu actions. Its exact item ID and title identify the backend without confusing
other apps using the same AppIndicator library. Plasma hides this native item;
it must remain running and registered because closing it also stops Synergy's
service. The custom tray never kills the Synergy service or core. Resume can
start the Flatpak service after a complete app exit. This integration follows
Synergy 3.6's exported menu protocol and reports changes as errors rather than
guessing at private service commands.

The tray starts the screen watcher while sharing runs and keyboard mappings are
enabled, and restores Linux mappings when either pauses. The controller binds
to the tray unit so systemd handles cleanup without detached process races.
Log rotation and truncation preserve screen state. Restarting xremap reasserts
the current screen's mode. Shortcut mappings and the Mac receiver are unchanged.

## Shortcut inspector

Open **Inspect shortcuts…** from the Synergy tray menu, or run
`synergy-keys inspect`. Search by shortcut or action, for example `thumb+l`,
`COMMAND-m`, `ctrl-shift+c`, or `grw windw`. Search ignores case and accepts
`+`, `-`, or spaces. Thumb means Linux Control; pinky, Meta, Super, Cmd and
Command mean Linux Meta. Select Keyboard or Logitech G903 to inspect the right
device rules. Capture chord listens only inside its field, after Linux remaps;
type desktop-reserved shortcuts as text instead of triggering them.

Results show the input, xremap rule, transport, every Mac app branch, and editable
source paths with line numbers. Linux Meta becomes Mac Command in transit;
there is no separate received encoding. The preview reads the current NixOS
checkout and local chezmoi checkout. **It does not observe delivery or query
the live Mac app**, and unapplied source edits may differ from running configs.
Refresh sources after editing. Manifest mismatches and unrecognized app detection
are reported instead of assuming the two sides agree. App-specific output is
the Hammerspoon key event; terminal/application bindings can interpret it further.

`synergy-keys inspect 'thumb+l' --json` prints a trace without a window or running
Synergy. Add `--device 'Logitech G903'` to inspect a mouse chord. Override checkout
paths with `SYNERGY_KEYS_NIXOS` and `SYNERGY_KEYS_DOTFILES`. If the NixOS checkout
is missing, the package provides a labeled build snapshot of the PC rules.

The inspector evaluates `inspector-data.nix`, which imports the actual xremap
modules without changing them. The Mac manifest supplies output chords; a small
reader recognizes the receiver's app-classification expression. If that expression
changes shape, extend `inspector_sources.py` or the UI will mark classification
unknown. Common-action descriptions live in `inspector.py` beside their receiver
source references; update them when changing those handlers.

For isolated GUI tests, use the package's Python with PyQt6 and
`QT_QPA_PLATFORM=offscreen` with `DISPLAY`, `WAYLAND_DISPLAY` unset and
`DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent`. Tests send events only to Qt
widgets; they never use evdev, uinput, ydotool, SSH, or live controller commands.
The tray's lifecycle methods are mocked. Build this package alone for a preview;
do not activate Home Manager or restart the tray just to test the inspector.

The canonical shortcut protocol lives in dotfiles
`dot_hammerspoon/synergy-keymap.json`. Its mirror is
`user/xremap/synergy-keymap.json`; keep both byte-identical. It covers 198
app-dependent chords, including Shift/Alt/Super variants. Common launch, close,
focus, growth, scroll, mouse gestures, and internal mode keys live separately in
`user/xremap/mac-common.nix`.

Super+H/J/K/L focuses Mac windows with the keyboard on its Linux layer.
Ctrl+H/J/K passes through unchanged; Ctrl+L sends real Control in terminals
and Command in other Mac apps. Native Mac Control-based desktop shortcuts
belong to the Mac keyboard layer and are not Synergy aliases.

Ctrl+wheel sends Command+Plus/Minus for Helium page zoom. Other apps receive
Command+wheel, including the Figma canvas.
Super+wheel still raises/lowers the hovered Mac window. These wheel rules apply
only in Mac modes. Zoom uses standard wheel reports and swallows the parallel
high-resolution reports, giving one zoom step per wheel detent. Stacking still
accepts both streams because it latches one action per burst direction.
The PC sends Hyper+PageUp/PageDown, reserved by Hammerspoon's `synergy-actions.lua`,
which resolves page versus wheel zoom on the Mac. xremap cannot emit wheel
events directly. Deploy the Mac receiver before activating these PC mappings.

Never allocate Ctrl+Alt+F1–F12 tokens without Shift. Linux intercepts them as
virtual console switches even with Meta held. Avoid Ctrl+Shift+Meta+arrows,
which KDE uses to move windows between desktops. Hyper+F9–F16 and Hyper+Y,
M/N, D/Escape, H/J/K/L are already reserved for other Mac actions.

Alt+W closes a Helium tab through an app-specific relay. T3 Code primary
shortcuts translate Ctrl to Command, including panel, palette, picker, thread
and model shortcuts; other apps and terminals keep their existing outputs.
Super+Shift+V/B grows windows down/right alongside Super+Alt+V/B. On a native
Mac keyboard layer the desktop modifier is Control.

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
