{ ... }:
{
  # The NixOS module installs the client and starts tailscaled at boot.
  # Device sign-in stays in Tailscale's local state, outside Git and the store.
  # Subnet forwarding and route advertisements are configured separately.
  services.tailscale.enable = true;
}
