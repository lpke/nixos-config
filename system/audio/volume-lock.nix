{ config, lib, pkgs, ... }:

let
  cfg = config.services.pipewire.audioVolumeLock;

  serviceName = service: lib.removeSuffix ".service" service;

  lockConfig = pkgs.writeText "audio-volume-locks.json" (builtins.toJSON (
    lib.mapAttrsToList
      (name: lock: {
        inherit name;
        inherit (lock) nodeName volume;
      })
      cfg.locks
  ));

  volumeLockScript = pkgs.writeShellApplication {
    name = "audio-volume-lock";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      pipewire
      pulseaudio
      wireplumber
    ];
    text = ''
      set -euo pipefail

      locks_json="${lockConfig}"
      event_delay="${toString cfg.intervalSeconds}"

      node_id() {
        node_name="$1"

        pw-dump | jq -r --arg node_name "$node_name" '
          .[]
          | select(.type == "PipeWire:Interface:Node")
          | select(.info.props."node.name" == $node_name)
          | select(
              .info.props."media.class" == "Audio/Source"
              or .info.props."media.class" == "Audio/Sink"
            )
          | .id
        ' | head -n1
      }

      apply_locks() {
        while read -r lock; do
          name="$(jq -r '.name' <<< "$lock")"
          node_name="$(jq -r '.nodeName' <<< "$lock")"
          volume="$(jq -r '.volume' <<< "$lock")"
          id="$(node_id "$node_name")"

          if [ -z "$id" ]; then
            continue
          fi

          wpctl set-volume -l 1.0 "$id" "$volume" || {
            echo "failed to lock volume for $name ($node_name -> $volume)" >&2
          }
        done < <(jq -c '.[]' "$locks_json")
      }

      while true; do
        apply_locks

        pactl subscribe 2>/dev/null | while read -r event; do
          case "$event" in
            *" on source "*|*" on sink "*|*" on server "*)
              apply_locks
              sleep "$event_delay"
              ;;
          esac
        done

        sleep "$event_delay"
      done
    '';
  };

  volumeLockStatus = pkgs.writeShellApplication {
    name = cfg.statusCommand;
    runtimeInputs = with pkgs; [
      coreutils
      jq
      pipewire
      systemd
      wireplumber
    ];
    text = ''
      set -euo pipefail

      locks_json="${lockConfig}"
      service="${cfg.service}"

      node_id() {
        pw-dump | jq -r --arg node_name "$1" '
          .[]
          | select(.type == "PipeWire:Interface:Node")
          | select(.info.props."node.name" == $node_name)
          | .id
        ' | head -n1
      }

      echo "audio volume locks:"
      echo "service: $service ($(systemctl --user is-active "$service" 2>/dev/null || true))"
      jq -c '.[]' "$locks_json" | while read -r lock; do
        name="$(jq -r '.name' <<< "$lock")"
        node_name="$(jq -r '.nodeName' <<< "$lock")"
        desired="$(jq -r '.volume' <<< "$lock")"
        id="$(node_id "$node_name")"

        if [ -z "$id" ]; then
          echo "$name: missing"
          echo "  node: $node_name"
          echo "  desired: $desired"
          continue
        fi

        current="$(wpctl get-volume "$id" 2>/dev/null)"
        current="''${current#Volume: }"
        echo "$name: present"
        echo "  node: $node_name"
        echo "  id: $id"
        echo "  desired: $desired"
        echo "  current: $current"
      done
    '';
  };
in
{
  options.services.pipewire.audioVolumeLock = {
    enable = lib.mkEnableOption "PipeWire volume locks";

    intervalSeconds = lib.mkOption {
      type = lib.types.str;
      default = "0.25";
      description = "Delay in seconds after audio change events before accepting another lock event.";
    };

    statusCommand = lib.mkOption {
      type = lib.types.str;
      default = "audio-volume-lock-status";
      description = "Command that prints configured audio volume locks.";
    };

    service = lib.mkOption {
      type = lib.types.str;
      default = "audio-volume-lock.service";
      description = "User systemd service name for the PipeWire volume lock daemon.";
    };

    locks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          nodeName = lib.mkOption {
            type = lib.types.str;
            description = "PipeWire node.name to lock. Numeric object IDs are not stable.";
          };

          volume = lib.mkOption {
            type = lib.types.str;
            example = "1.00";
            description = "Volume to enforce. PipeWire uses 1.00 for 100%.";
          };
        };
      });
      default = {};
      description = "Audio input/output volumes to continuously force.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services = {
      ${serviceName cfg.service} = {
        description = "Force configured PipeWire input/output volumes";
        wantedBy = [ "default.target" ];
        after = [ "pipewire.service" "wireplumber.service" ];
        partOf = [ "pipewire.service" ];
        restartIfChanged = true;
        serviceConfig = {
          ExecStart = "${lib.getExe volumeLockScript}";
          Restart = "always";
          RestartSec = "1s";
        };
      };
    };

    system.userActivationScripts.audioVolumeLock = {
      deps = [];
      text = ''
        ${pkgs.systemd}/bin/systemctl --user reset-failed ${lib.escapeShellArg cfg.service} 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl --user restart ${lib.escapeShellArg cfg.service} 2>/dev/null || true
      '';
    };

    environment.systemPackages = [
      volumeLockStatus
    ];
  };
}
