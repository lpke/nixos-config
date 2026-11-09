# T3 Tailscale helper

`t3-tailscale` adds scoped route controls to the existing boot-starting Tailscale
daemon. Home Manager installs the command in `user/t3-tailscale.nix`. The
independent [`t3-tray`](../t3-tray/README.md) package supplies its login-starting
combined tray. The system module grants the local user
Tailscale operator permission so controls need no interactive sudo.

Private settings come from `~/.config/tailscale-config/t3-gateway.json`, provisioned
only by the explicitly enabled chezmoi external. The file contains a single-host
IPv4 route, its HTTP URL and the expected public T3 environment ID. No credential
or encrypted T3 catalog is read. The private repository owns target values and
operating instructions; `help.md` is rendered with those values at runtime.

Start merges the T3 route into the daemon's current advertisements. Pause and
Quit remove only that route. All other advertisements and preferences are kept.
Both leave the shared tray and SSH connection running. A per-user lock serializes these read/modify/write
operations. Route preferences persist across reboots, so Pause needs an explicit
Start to resume. The shared tray starts at login independently of T3 app launches.

Status requires a running Tailscale connection, advertisement and approval of the
configured route, kernel forwarding, source NAT, and an HTTP public descriptor
matching the configured environment ID. It does not claim that phone pairing or
a remote phone's last-mile connection has been tested. No SSH probe is performed.

Tailscale status is the solid left half of the combined T3 ring. Aqua means the
gateway and configured Mac are ready. Red includes paused/error states. The shared
tray owns menus and rendering; this package has no Qt dependency or separate tray.

Validation uses mocked route/state tests and offscreen Qt menu/shutdown tests,
followed by a NixOS build and a live pause/start/quit/start cycle. Never stop the
shared SSH master or daemon when testing this helper.
