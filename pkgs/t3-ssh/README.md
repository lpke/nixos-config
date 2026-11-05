# T3 SSH connection

`t3-ssh` controls a Home Manager user target containing the SSH tunnel.
`user/t3-ssh.nix` owns its destination settings and units. The package supplies
commands, credential-free health checks and help. The independent
[`t3-tray`](../t3-tray/README.md) package supplies the combined connection tray.

Native SSH is the preferred saved route for the Mac environment, with existing
HTTP routes retained as backups. T3 stores these locally rather than managing
secrets in Nix. VSCode's Remote SSH client uses the shared master through the host alias.
T3 0.1.7 only derives editor links from the active SSH profile or the server's
advertised SSH targets, so an alternate SSH profile alone does not enable its
editor button on HTTP. Its native SSH tunnel also forces `ControlPath=none`.
The persistent forward is available for health checks and optional URL pairing;
a URL route alone carries no SSH editor metadata. See `help.txt` for use.

The chezmoi `t3code` launcher calls `t3-ssh auto-start` when this optional helper
is available. A locked runtime marker contains the current graphical session's
invocation id. Only its first launch starts the target. Explicit start, pause,
and quit also record that session so later app windows respect those choices.
The next graphical session can start automatically on first T3 use, including
when the user manager lingers across logouts.

The SSH target and tunnel have no `WantedBy` and are never enabled for login or
boot. The target is part of the graphical session, and the tunnel is part of the
target. Pause stops only the tunnel. Quit stops the SSH target and tunnel, while
leaving the shared T3 tray and Tailscale route alone. Explicit Start also shows
the shared tray. Closing T3 or quitting the tray never stops the tunnel.

The held remote sleep keeps a multiplexed SSH client in the foreground for
systemd to supervise. A forced remote PTY hangs up that helper when the client
stops, preventing abandoned sessions from filling SSH's session slots.
`ExecStop` cancels only this listener through the master;
established forwarded connections can remain alive until their clients close.
Other SSH sessions are unaffected. `ControlPersist=yes` keeps an authenticated
master available; keepalive changes do not reconfigure an existing master.

Connection status checks the tunnel service and the public T3 descriptor over
loopback, with proxies disabled and a two-second timeout. It requires a T3
environment id and the configured remote operating system. It never opens the
desktop's encrypted catalog, reads tokens, or tests remote project access.
Consequently a green ring confirms transport/server readiness, not valid T3
pairing credentials. The tray runs each check in a child process so an offline
Mac does not block menu interactions.

The SSH status is the dotted right half of the combined T3 ring. Aqua means
the SSH forward reaches the expected T3 server; red includes paused/error states.
See the combined tray guide for rendering, menus and Qt tests.

Run controller tests without touching live services:

```sh
PYTHONPATH=pkgs/t3-ssh python3 -B -m unittest discover -s pkgs/t3-ssh -v
```
