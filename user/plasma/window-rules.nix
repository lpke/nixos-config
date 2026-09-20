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
  (lib.recursiveUpdate (mkAdaptiveSyncRule {
    description = "Minecraft Beta - GSync";
    windowClass = "Minecraft Minecraft Beta 1.7.3";
  }) {
    # LWJGL uses the same versioned string for both resource name and class.
    match.window-class.match-whole = false;
    # Ignore LWJGL's position hint, which otherwise overrides the initial screen.
    apply.ignoregeometry = {
      value = true;
      apply = "force";
    };
    apply.screen = {
      # KWin 6.6 output index: HDMI-A-1 (Alienware), zero-based.
      value = 2;
      apply = "initially";
    };
  })

  (mkAdaptiveSyncRule {
    description = "RuneLite - GSync";
    windowClass = "net-runelite-client-RuneLite";
  })
]
