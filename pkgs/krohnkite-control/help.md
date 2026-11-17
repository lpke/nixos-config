# Krohnkite

Krohnkite automatically tiles windows. Its tray stays available when tiling is stopped.

| Command | Action |
| --- | --- |
| `krohnkite` | Open the tray and start tiling. |
| `krohnkite start` | Start tiling and restore the tray if needed. |
| `krohnkite stop` | Stop tiling, keeping the tray available. |
| `krohnkite status` | Show whether tiling is running. |
| `krohnkite reload` | Apply settings while keeping layout choices. |
| `krohnkite restart` | Replace the tiling script and reset layout choices. |
| `krohnkite recover` | Clear stranded callbacks by restarting all KWin scripts. |
| `krohnkite help` | Open this guide in a new terminal window. |
| `krohnkite quit` | Stop tiling and close the tray. |
| `krohnkite --help` | Print command options. |

The tray and tiling start at desktop login. Stop lasts until Start, app launch,
a tray restart, or the next login. Quitting or killing the tray also stops tiling. Launch
Krohnkite from the application launcher to restore both.

Reload preserves tile order, proportions and manual floating choices. Window
class/title defaults apply to newly opened windows. Restart resets runtime
layout choices. Recover restarts other enabled KWin scripts too, without
closing apps or restarting the compositor.
