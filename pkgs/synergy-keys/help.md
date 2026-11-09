# Synergy

The tray controls Synergy sharing and keyboard mappings independently. Its colored
ring means sharing is running; its white pointer means mappings are ready.
Red marks a stopped, paused or unavailable part.

Synergy carries the keyboard and mouse between computers. synergy-keys watches
which screen is active and selects the matching keyboard mappings. Its controller
runs only while sharing and its tray are active; the two pause choices are independent.
Launch Synergy from the app menu or command to open sharing and these controls.

| Command | Action |
| --- | --- |
| `synergy` | Start sharing and show the custom controls. |
| `synergy-keys tray` | Restore the tray without changing pause choices. |
| `synergy-keys quit` | Quit Synergy and its controls; restore Linux mappings. |
| `synergy-keys` | Show sharing and mapping status. |
| `synergy-keys pause` / `resume` | Pause or resume keyboard mappings. |
| `synergy-keys synergy pause` / `resume` | Pause or resume sharing. |
| `synergy-keys synergy config` | Open Synergy configuration. |
| `synergy-keys refresh` | Refresh screen detection without clearing a pause. |
| `synergy-keys inspect` | Inspect a shortcut's configured route. |
| `synergy-keys logs` | Show controller and tray logs. |
| `synergy-keys --help` | Show all command options. |

Pause choices persist. Pausing mappings restores Linux keys; resuming while
sharing is stopped arms the next session. Keep Synergy's hidden native tray
running: it supplies the sharing controls.

Use `synergy-keys inspect 'thumb+l' --json` for a text trace. Add
`--device 'Logitech G903'` for mouse shortcuts. Inspection reads configured
mappings; it does not test delivery to a Mac app.
