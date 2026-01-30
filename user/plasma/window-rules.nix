# See: https://github.com/nix-community/plasma-manager/blob/trunk/modules/window-rules.nix
{ lib }:

let
  windowDecorations = (import ./apps/windowDecorations.nix).window-rules;

in
  # merged-in configs:
  windowDecorations ++
# all other configs:
[
  # GSync for Minecraft Beta
  {
    description = "Minecraft Beta";
    match = {
      window-class = {
        value = "Minecraft Minecraft Beta 1.7.3";
        type = "exact";
      };
    };
    apply = {
      adaptivesync = {
        value = true;
        apply = "force";
      };
    };
  }

  # GSync for RuneLite
  {
    description = "RuneLite";
    match = {
      window-class = {
        value = "net-runelite-client-RuneLite";
        type = "exact";
      };
    };
    apply = {
      adaptivesync = {
        value = true;
        apply = "force";
      };
    };
  }
]
