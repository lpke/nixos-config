# These settings are imported and merged into the rest of the plasma-manager config

{
  krunner = {
    position = "top";
    activateWhenTypingOnDesktop = true;
    historyBehavior = "enableSuggestions"; # disabled | enableSuggestions | enableAutoComplete

    shortcuts = {
      launch = "Meta+Space"; # default: Search, Alt+Space, Alt+F2
      runCommandOnClipboard = [];
    };
  };

  configFile = {
    krunnerrc = {
      # plugins with priority in search results
      "Plugins/Favorites".plugins = "krunner_services,krunner_sessions,krunner_powerdevil,krunner_systemsettings";
      Plugins.baloosearchEnabled = true; # use indexed search
      Plugins.krunner_webshortcutsEnabled = false;
    };
  };
}
