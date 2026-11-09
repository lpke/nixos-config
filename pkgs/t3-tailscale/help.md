# T3 Tailscale gateway

Your phone reaches the Mac through this PC's Tailscale route. The Mac receives
normal LAN traffic and needs no Tailscale or SSH listener for this route.
Desktop T3 keeps SSH first; HTTP remains an independent backup.

## Controls

| Command | Action |
| --- | --- |
| `t3-tailscale start` | Advertise the T3 route and show the tray. |
| `t3-tailscale stop` | Pause this route. |
| `t3-tailscale status` | Check approval, forwarding and Mac identity. |
| `t3-tailscale logs` | Show tray and Tailscale logs. |
| `t3-tailscale quit` | Pause this route; keep SSH and the tray. |

Pause withdraws only `@ROUTE@` and persists until Start, including after reboot.
Other routes and shared Tailscale settings stay intact. The daemon starts at
boot; the tray starts at desktop login. Closing T3 or quitting the tray does not
stop the gateway. Use `t3-tray show` to restore the icon.

The upper-left ring quarter reports Tailscale, the lower-left reports Git review,
and the dotted right half reports SSH. Aqua confirms gateway and Mac readiness,
not the phone's connectivity or pairing permission.

## Use and pair

Keep both computers awake and Mac T3 Network access enabled. Connect the phone's
Tailscale app to the same personal account, then open its saved Mac environment.
The PC's T3 app can be closed. Address: `@URL@`.

For a new phone or expired permission:

1. On the Mac, open T3 Settings > Sharing & access and select its local environment.
2. Create a fresh link with control access. Expand Share > Copy code only or use
   the QR code. Each client needs its own code; used codes cannot be reused.
3. On the phone, add the environment at `@URL@` with that code.
4. Open an existing thread. Test with Wi-Fi off and mobile data on to verify VPN access.

## Recovery and ownership

Run `t3-tailscale status` and `t3-tailscale logs`. Check Mac power and T3 Network
access. For missing approval, open [Tailscale Machines](https://login.tailscale.com/admin/machines),
select this PC and approve only `@ROUTE@` under Subnets. If signed out, run
`tailscale up` and complete its browser login.

NixOS owns forwarding, filtering and operator permission. The private
`~/.config/tailscale-config/t3-gateway.json` owns the target. Its README and
`docs/t3-mac-access.md` cover policy, source NAT and recovery. Read them before
changing shared settings. Pulling policy from Git does not publish it to Tailscale.
Credentials remain in Tailscale and T3.
