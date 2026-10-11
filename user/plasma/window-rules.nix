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
  {
    description = "Adobe Creative Cloud - allow resizing";
    match.window-types = [ "normal" ];
    match.window-class = {
      value = "creative cloud.exe";
      type = "exact";
      match-whole = false;
    };
    # Creative Cloud sets identical minimum and maximum sizes under Wine.
    # Override those hints so KWin and Krohnkite can resize its main window.
    apply = {
      minsize = { value = "1656,900"; apply = "force"; };
      maxsize = { value = "32767,32767"; apply = "force"; };
    };
  }

  {
    description = "Adobe Photoshop - keep tiling stable";
    match.window-types = [ "normal" ];
    match.window-class = {
      value = "photoshop.exe";
      type = "exact";
      match-whole = false;
    };
    # Wine can classify Photoshop's screen-sized startup window as fullscreen.
    # It repeats this during resizing, not just startup. Keep the managed window
    # out of fullscreen so Krohnkite owns its geometry throughout the session.
    apply.fullscreen = { value = false; apply = "force"; };
  }

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
    # Screen placement follows KDE's primary output in minecraft-primary-screen.js.
  })

  (mkAdaptiveSyncRule {
    description = "RuneLite - GSync";
    windowClass = "net-runelite-client-RuneLite";
  })
]
