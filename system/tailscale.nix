{ config, ... }:
{
  # NixOS owns the boot-starting daemon and kernel forwarding.
  # Personal route destinations and policy live in the private configuration
  # checkout; tailscale set stores its portable preferences in daemon state.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Restrict the new forwarding role without changing host input/output policy.
  # Tailscale enforces destination/user access before packets enter its interface.
  # Keep daemon-managed tables intact and run this guard after their filter hook.
  networking.nftables = {
    enable = true;
    flushRuleset = false;
    tables.tailscale-forwarding = {
      family = "inet";
      content = ''
        chain forward {
          type filter hook forward priority 10; policy drop;
          ct state invalid drop
          ct state established,related accept
          iifname "${config.services.tailscale.interfaceName}" accept
        }
      '';
    };
  };
}
