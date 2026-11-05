# T3 Tailscale helper

`t3-tailscale` adds scoped route controls and a login-starting Qt tray to the
existing boot-starting Tailscale daemon. Home Manager owns the command and tray
service in `user/t3-tailscale.nix`. The system module grants the local user
Tailscale operator permission so controls need no interactive sudo.

Private settings come from `~/.config/tailscale-config/t3-gateway.json`, provisioned
only by the explicitly enabled chezmoi external. The file contains a single-host
IPv4 route, its HTTP URL and the expected public T3 environment ID. No credential
or encrypted T3 catalog is read. The private repository owns target values and
operating instructions; `help.txt` is rendered with those values at runtime.

Start merges the T3 route into the daemon's current advertisements. Pause and
Quit remove only that route. All other advertisements and preferences are kept.
Quit additionally stops the tray. A per-user lock serializes these read/modify/write
operations. Route preferences persist across reboots, so Pause needs an explicit
Start to resume. The tray starts at login independently of T3 app launches.

Status requires a running Tailscale connection, advertisement and approval of the
configured route, kernel forwarding, source NAT, and an HTTP public descriptor
matching the configured environment ID. It does not claim that phone pairing or
a remote phone's last-mile connection has been tested. No SSH probe is performed.

The tray uses the shared `pkgs/t3-connection-tray` UI and the SSH helper's T3 glyph
with a dotted status ring. Both tray wrappers keep their separate service IDs and
commands. Package wrappers install the shared module, Qt SVG/Wayland plugins and
required CLI paths. The common tray keeps status checks asynchronous and kills
only its own child processes before Qt destroys them.

Validation uses mocked route/state tests and offscreen Qt menu/shutdown tests,
followed by a NixOS build and a live pause/start/quit/start cycle. Never stop the
shared SSH master or daemon when testing this helper.
