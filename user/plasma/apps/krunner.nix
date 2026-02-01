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
      Plugins.baloosearchEnabled = true; # use indexed search
      Plugins.krunner_webshortcutsEnabled = false;
      # Plugins.krunner_appstreamEnabled = false;
      # "Plugins/Favorites".plugins = "krunner_sessions,krunner_powerdevil,krunner_services,krunner_systemsettings";
    };

  };
}
