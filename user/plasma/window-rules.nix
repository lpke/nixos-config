# See: https://github.com/nix-community/plasma-manager/blob/trunk/modules/window-rules.nix
{ lib, withApp }:

let
  windowDecorations = (withApp "windowDecorations").window-rules;

  mkAdaptiveSyncRule = { description, windowClass, matchType ? "exact" }:
    {
      description = description;
      match = {
        window-class = {
          value = windowClass;
          type = matchType;
        };
      };
      apply = {
        adaptivesync = {
          value = true;
          apply = "force";
        };
      };
    };

in
  # merged-in configs:
  windowDecorations ++
# all other configs:
[
  (mkAdaptiveSyncRule {
    description = "Minecraft Beta - GSync";
    windowClass = "Minecraft Minecraft Beta 1.7.3";
  })

  (mkAdaptiveSyncRule {
    description = "RuneLite - GSync";
    windowClass = "net-runelite-client-RuneLite";
  })
]
