# Synergy

The tray controls Synergy sharing and keyboard mappings independently. Its colored
ring means sharing is running; its white pointer means mappings are ready.
Red marks a stopped, paused or unavailable part.

| Command | Action |
| --- | --- |
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
