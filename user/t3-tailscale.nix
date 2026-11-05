{ pkgs, ... }:
let
  helper = pkgs.callPackage ../pkgs/t3-tailscale {};
in
{
  home.file.".local/bin/t3-tailscale".source = "${helper}/bin/t3-tailscale";
}
