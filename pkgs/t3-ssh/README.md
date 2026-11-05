# T3 SSH connection

`t3-ssh` controls a Home Manager user target containing the SSH tunnel and a
Qt tray. `user/t3-ssh.nix` owns the destination settings and unit definitions.
The package provides the command, asynchronous tray status checks, help text,
and icons. `system/help/help.txt` lists the public commands.

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

The units have no `WantedBy` and are never enabled for login or boot. The target
is part of the graphical session, and both services are part of the target.
Pausing stops only the tunnel. Quitting stops the target and both services.
Neither closing T3 nor a tray process crash stops the tunnel. A failed tray
process is restarted independently.
The tray disconnects and stops outstanding child processes before Qt teardown,
including when Quit interrupts a pending health check.
Its Qt implementation is shared with T3 Tailscale in `pkgs/t3-connection-tray`;
each package supplies its own command, display name, icons and service identity.

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

Plasma's tray item id is `T3 SSH`. Its panel definition always shows the icon
while the tray service is running. The icons use Synergy's 32px canvas, 10.6px ring radius
and 2.8px stroke. The white glyphs are T3's original vector letter shapes with
their background removed. See `icons/LICENSE-T3` for the upstream MIT notice.

Run the controller tests with:

```sh
PYTHONPATH=pkgs/t3-ssh:pkgs/t3-tailscale:pkgs/t3-connection-tray python3 -B -m unittest discover -s pkgs/t3-ssh -v
```

Qt tests use the package Python, `QT_QPA_PLATFORM=offscreen`, an isolated D-Bus
session and no live service commands. Live lifecycle checks should leave the
Mac app and unrelated SSH sessions running.
With PyQt6 available, `python3 -B pkgs/t3-connection-tray/test_trays.py` runs both
transport tray suites and supplies an explicit isolated D-Bus configuration.
