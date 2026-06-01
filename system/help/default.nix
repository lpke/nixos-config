{ config, lib, pkgs, ... }:

let
  cfg = config.programs.localHelp;
in
{
  options.programs.localHelp = {
    enable = lib.mkEnableOption "local custom command help";

    commandName = lib.mkOption {
      type = lib.types.str;
      default = "help";
      description = "Command name installed for local custom command help.";
    };

    textFile = lib.mkOption {
      type = lib.types.path;
      default = ./help.txt;
      description = "Static help text printed by the local help command.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = cfg.commandName;
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          cat ${cfg.textFile}
        '';
      })
    ];
  };
}
