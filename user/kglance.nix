{ config, lib, pkgs, ... }:

let
  kglance = pkgs.callPackage ../pkgs/kglance {};
  dolphinUiFile = "${config.xdg.dataHome}/kxmlgui5/dolphin/dolphinui.rc";
  previewAction = "servicemenu_kglance-rust.desktop::previewWithRust";
in
{
  home.packages = [ kglance ];

  systemd.user.services.kglance = {
    Unit = {
      Description = "Kglance quick-preview daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe kglance} daemon";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.configureKglanceDolphinShortcut =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ui_file=${lib.escapeShellArg dolphinUiFile}
      ui_dir="$(${pkgs.coreutils}/bin/dirname "$ui_file")"
      preview_action=${lib.escapeShellArg previewAction}

      run ${pkgs.coreutils}/bin/mkdir -p "$ui_dir"

      if [ ! -f "$ui_file" ]; then
        run ${pkgs.coreutils}/bin/install -m 0644 \
          ${./kglance/dolphinui.rc} "$ui_file"
      fi

      run ${pkgs.xmlstarlet}/bin/xmlstarlet ed --inplace \
        -d "/gui/ActionProperties[@scheme='Default']/Action[@name='toggle_selection_mode']" \
        -d "/gui/ActionProperties[@scheme='Default']/Action[@name='$preview_action']" \
        -s "/gui/ActionProperties[@scheme='Default']" -t elem -n ActionTMP -v "" \
        -i "/gui/ActionProperties[@scheme='Default']/ActionTMP[last()]" -t attr -n name -v "toggle_selection_mode" \
        -i "/gui/ActionProperties[@scheme='Default']/ActionTMP[last()]" -t attr -n shortcut -v "" \
        -r "/gui/ActionProperties[@scheme='Default']/ActionTMP[last()]" -v Action \
        -s "/gui/ActionProperties[@scheme='Default']" -t elem -n ActionTMP -v "" \
        -i "/gui/ActionProperties[@scheme='Default']/ActionTMP[last()]" -t attr -n name -v "$preview_action" \
        -i "/gui/ActionProperties[@scheme='Default']/ActionTMP[last()]" -t attr -n shortcut -v "Space" \
        -r "/gui/ActionProperties[@scheme='Default']/ActionTMP[last()]" -v Action \
        "$ui_file"
    '';
}
