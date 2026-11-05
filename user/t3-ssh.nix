{ lib, pkgs, ... }:
let
  t3Ssh = pkgs.callPackage ../pkgs/t3-ssh {};
  settings = {
    ssh_host = "mbp";
    local_port = 13773;
    remote_port = 3773;
    remote_os = "darwin";
  };
  forward = "127.0.0.1:${toString settings.local_port}:127.0.0.1:${toString settings.remote_port}";
  ssh = "${pkgs.openssh}/bin/ssh";
in
{
  xdg.configFile."t3-ssh/config.json".text = builtins.toJSON settings;
  home.file.".local/bin/t3-ssh".source = "${t3Ssh}/bin/t3-ssh";

  # No WantedBy: the launcher explicitly starts this group on first T3 use.
  # Neither closing T3 nor a later app launch changes a paused/quit group.
  systemd.user.targets.t3-ssh.Unit = {
    Description = "Persistent T3 SSH connection and tray";
    Wants = [ "t3-mbp-tunnel.service" "t3-ssh-tray.service" ];
    PartOf = [ "graphical-session.target" ];
  };

  systemd.user.services.t3-mbp-tunnel = {
    Unit = {
      Description = "T3 Code connection through shared SSH";
      PartOf = [ "t3-ssh.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      # A held remote session keeps a multiplexed client in the foreground.
      # -N alone would exit after asking an existing master for the forward.
      # Force a remote PTY so closing the channel hangs up the sleep process.
      # Without it, stopped sessions can linger and exhaust MaxSessions.
      ExecStart = lib.escapeShellArgs [
        ssh "-tt" "-o" "BatchMode=yes" "-o" "ConnectTimeout=10"
        "-o" "ControlMaster=auto" "-o" "ControlPersist=yes"
        "-o" "ExitOnForwardFailure=yes" "-o" "ServerAliveInterval=30"
        "-o" "ServerAliveCountMax=3" "-L" forward
        settings.ssh_host "exec" "sleep" "2147483647"
      ];
      # The master owns forwarded listeners, so cancel this one explicitly.
      ExecStop = "-" + lib.escapeShellArgs [
        ssh "-o" "BatchMode=yes" "-o" "ConnectTimeout=5"
        "-O" "cancel" "-L" forward settings.ssh_host
      ];
      Restart = "always";
      # A multiplexed ssh client can return 255 when its session is stopped.
      # Real failures still restart because Restart=always.
      SuccessExitStatus = [ 255 ];
      RestartSec = 5;
      TimeoutStopSec = 10;
    };
  };

  systemd.user.services.t3-ssh-tray = {
    Unit = {
      Description = "T3 SSH connection status and controls";
      After = [ "graphical-session.target" ];
      PartOf = [ "t3-ssh.target" ];
    };
    Service = {
      ExecStart = "${t3Ssh}/bin/t3-ssh-tray";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
