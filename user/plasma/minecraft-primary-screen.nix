{ ... }:

{
  programs.plasma.configFile.kwinrc.Plugins.minecraft-primary-screenEnabled = true;

  xdg.dataFile = {
    "kwin/scripts/minecraft-primary-screen/metadata.json".text = builtins.toJSON {
      KPlugin = {
        Id = "minecraft-primary-screen";
        Name = "Minecraft on primary display";
        Description = "Open Minecraft on the primary display selected in KDE settings";
        Version = "1.0";
        License = "MIT";
      };
      "X-Plasma-API" = "javascript";
      "X-Plasma-MainScript" = "code/main.js";
      "KPackageStructure" = "KWin/Script";
    };
    "kwin/scripts/minecraft-primary-screen/contents/code/main.js".source =
      ./minecraft-primary-screen.js;
  };
}
