{ ... }:

{
  programs.plasma = {
    configFile.kwinrc.Plugins.directional-focusEnabled = true;
    shortcuts.kwin = {
      DirectionalFocusLeft = "Meta+h";
      DirectionalFocusDown = "Meta+j";
      DirectionalFocusUp = "Meta+k";
      DirectionalFocusRight = "Meta+l";
    };
  };

  xdg.dataFile = {
    "kwin/scripts/directional-focus/metadata.json".text = builtins.toJSON {
      KPlugin = {
        Id = "directional-focus";
        Name = "Directional window focus";
        Description = "Use Krohnkite tile neighbors when available, otherwise native KWin focus";
        Version = "1.0";
        License = "MIT";
      };
      "X-Plasma-API" = "javascript";
      "X-Plasma-MainScript" = "code/main.js";
      "KPackageStructure" = "KWin/Script";
    };
    "kwin/scripts/directional-focus/contents/code/main.js".source = ./directional-focus.js;
  };
}
