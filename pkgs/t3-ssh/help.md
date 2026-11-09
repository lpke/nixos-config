# T3 SSH

Keep the Mac's SSH route first in desktop T3, with HTTP as backup. The PC also
forwards `@LOCAL_URL@` for health checks and optional URL pairing.

## Controls

| Command | Action |
| --- | --- |
| `t3-ssh start` | Start or resume SSH and show the tray. |
| `t3-ssh stop` | Pause SSH. |
| `t3-ssh status` | Check the tunnel and Mac T3 server. |
| `t3-ssh logs` | Show connection and tray logs. |
| `t3-ssh quit` | Stop SSH; keep Tailscale and the tray. |
| `t3-tray show` | Restore the tray without starting connections. |

The first T3 launch per desktop login starts SSH. Closing T3 leaves it running;
later launches respect Pause and Quit. SSH does not start at boot or login.
The tray starts at login. Its dotted right ring reports SSH; the upper-left
quarter reports Tailscale and the lower-left quarter reports Git review.
Quitting the tray leaves those helpers running.

## Connect and pair

1. Keep T3 running and the Mac awake. On the PC, open Settings > Environments,
   enable the Mac, and put SSH `@SSH_HOST@` first under Routes.
2. Open a Mac thread or choose the Mac under Run on for a new thread.
   `uname -s` in its terminal should print `Darwin`.
3. To pair or renew permission, open T3 Settings > Sharing & access on the Mac.
   Create a link with the required permissions, then expand Share > Copy code
   only. Keep that page open while pairing.
4. On the PC, use Add environment or Add route. Enter `@LOCAL_URL@` as Host and
   paste the pairing code. Keep native SSH first after pairing.

T3 saves its token separately from SSH. A green ring checks transport, not token
expiry. Open in VSCode needs an active SSH route or advertised SSH editor target;
saving an unused SSH route is insufficient. VSCode can use the shared SSH master,
but T3's native route needs a fresh SSH connection.

## Recovery

Run `t3-ssh status` and `t3-ssh logs`. Check Mac power, networking and T3, then try
`ssh @SSH_HOST@` and `t3-ssh start`. The helper retries while started, but cannot
preserve a connection across reboots, lost networking, unavailable keys or server
policy changes.

If Remote Login is disabled, an authorized Mac administrator can run:

```sh
sudo systemsetup -setremotelogin on
sudo dseditgroup -o edit -a luke -t user com.apple.access_ssh
```

Management policy can disable it again. A healthy existing tunnel does not prove
that a fresh native SSH connection is allowed.
