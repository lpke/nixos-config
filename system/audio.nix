{ config, lib, pkgs, ... }:

let
  cfg = config.services.pipewire.audioRouting;

  outputName = displayName: cfg.outputs.${displayName};

  outputId = displayName:
    lib.toLower (builtins.replaceStrings
      [ " " "+" "-" "." "/" "(" ")" ]
      [ "_" "plus" "_" "_" "_" "" "" ]
      displayName);

  referencedOutputNames =
    [ cfg.cubiluxLoopback.output ]
    ++ lib.concatMap (combinedOutput: combinedOutput.outputs) cfg.combinedOutputs;

  missingOutputNames = lib.unique (lib.filter
    (displayName: !(builtins.hasAttr displayName cfg.outputs))
    referencedOutputNames);

  invalidCombinedOutputs = lib.filter
    (combinedOutput: builtins.length combinedOutput.outputs < 2)
    cfg.combinedOutputs;

  serviceName = service: lib.removeSuffix ".service" service;

  shellArrayItems = values:
    lib.concatMapStringsSep "\n" (value: "        ${lib.escapeShellArg value}") values;

  mkCombinedAudioOutput = combinedOutput: {
    name = "libpipewire-module-combine-stream";
    args = {
      "combine.mode" = "sink";
      "node.name" = "combined_${lib.concatStringsSep "_" (map outputId combinedOutput.outputs)}";
      "node.description" = combinedOutput.name;
      "combine.latency-compensate" = false;
      "combine.props" = {
        "audio.position" = [ "FL" "FR" ];
      };
      "stream.props" = {
        "stream.dont-remix" = true;
      };
      "stream.rules" = map (output: {
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.name" = outputName output;
          }
        ];
        actions = {
          "create-stream" = {
            "combine.audio.position" = [ "FL" "FR" ];
            "audio.position" = [ "FL" "FR" ];
          };
        };
      }) combinedOutput.outputs;
    };
  };

  managedLoopbacks = {
    output = {
      command = cfg.commands.outputToggle;
      inherit (cfg.outputLoopback) service nodeName route;
      outputTarget = "@DEFAULT_AUDIO_SINK@";
      outputFallback = "@DEFAULT_AUDIO_SINK@";
      startByDefault = false;
    };

    cubilux = {
      command = cfg.commands.cubiluxToggle;
      inherit (cfg.cubiluxLoopback) service nodeName route;
      outputTarget = outputName cfg.cubiluxLoopback.output;
      outputFallback = cfg.cubiluxLoopback.output;
      startByDefault = cfg.cubiluxLoopback.enable;
    };
  };

  managedLoopbackList = [
    managedLoopbacks.output
    managedLoopbacks.cubilux
  ];
  managedLoopbackServices = map (loopback: loopback.service) managedLoopbackList;
  managedLoopbackNodeNames = lib.concatMap
    (loopback: [
      "input.${loopback.nodeName}"
      "output.${loopback.nodeName}"
    ])
    managedLoopbackList;

  mkAudioLoopbackToggle = loopback: pkgs.writeShellApplication {
    name = loopback.command;
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      systemd
      wireplumber
    ];
    text = ''
      set -euo pipefail

      service="${loopback.service}"
      route="${loopback.route}"
      output_target="${loopback.outputTarget}"
      output_fallback="${loopback.outputFallback}"

      usage() {
        echo "usage: ${loopback.command} [--status]" >&2
      }

      node_description() {
        wpctl inspect "$1" 2>/dev/null \
          | sed -n 's/^  \* node.description = "\(.*\)"$/\1/p' \
          | head -n1
      }

      service_state() {
        systemctl --user is-active "$service" 2>/dev/null || true
      }

      print_status() {
        state="$(service_state)"
        if [ "$state" = "active" ]; then
          enabled="on"
        else
          enabled="off"
        fi

        input="$(node_description @DEFAULT_AUDIO_SOURCE@ || true)"
        output="$(node_description "$output_target" || true)"
        if [ -z "$input" ]; then
          input="@DEFAULT_AUDIO_SOURCE@"
        fi
        if [ -z "$output" ]; then
          output="$output_fallback"
        fi

        echo "$enabled: $route"
        echo "input: $input"
        echo "output: $output"
        echo "service: $service ($state)"
      }

      if [ "$#" -gt 1 ]; then
        usage
        exit 2
      fi

      case "''${1:-}" in
        --status)
          print_status
          ;;
        "")
          if systemctl --user is-active --quiet "$service"; then
            systemctl --user stop "$service" || {
              print_status
              exit 1
            }
          else
            systemctl --user start "$service" || {
              print_status
              exit 1
            }
          fi
          print_status
          ;;
        *)
          usage
          exit 2
          ;;
      esac
    '';
  };

  audioLoopbackOutputToggle = mkAudioLoopbackToggle managedLoopbacks.output;
  audioLoopbackCubiluxToggle = mkAudioLoopbackToggle managedLoopbacks.cubilux;

  audioLoopbackRebind = pkgs.writeShellApplication {
    name = cfg.commands.rebind;
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      set -euo pipefail

      services=(
${shellArrayItems managedLoopbackServices}
      )
      active_services=()

      for service in "''${services[@]}"; do
        if systemctl --user is-active --quiet "$service"; then
          active_services+=("$service")
        fi
      done

      systemctl --user stop "''${services[@]}" 2>/dev/null || true

      if [ "''${#active_services[@]}" -eq 0 ]; then
        echo "no active managed loopbacks to rebind"
        exit 0
      fi

      systemctl --user start "''${active_services[@]}"
      echo "rebound managed loopbacks:"
      printf '  %s\n' "''${active_services[@]}"
    '';
  };

  audioLoopbackStatus = pkgs.writeShellApplication {
    name = cfg.commands.status;
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      jq
      pipewire
      systemd
      wireplumber
    ];
    text = ''
      set -euo pipefail

      node_description() {
        wpctl inspect "$1" 2>/dev/null \
          | sed -n 's/^  \* node.description = "\(.*\)"$/\1/p' \
          | head -n1
      }

      print_managed_status() {
        service="$1"
        route="$2"
        output_target="$3"
        output_fallback="$4"

        state="$(systemctl --user is-active "$service" 2>/dev/null || true)"
        if [ "$state" = "active" ]; then
          enabled="on"
        else
          enabled="off"
        fi

        input="$(node_description @DEFAULT_AUDIO_SOURCE@ || true)"
        output="$(node_description "$output_target" || true)"
        if [ -z "$input" ]; then
          input="@DEFAULT_AUDIO_SOURCE@"
        fi
        if [ -z "$output" ]; then
          output="$output_fallback"
        fi

        echo "$service: $enabled ($state)"
        echo "  route: $route"
        echo "  input: $input"
        echo "  output: $output"
      }

      echo "managed loopbacks:"
${lib.concatMapStringsSep "\n" (loopback: ''
      print_managed_status \
        ${lib.escapeShellArg loopback.service} \
        ${lib.escapeShellArg loopback.route} \
        ${lib.escapeShellArg loopback.outputTarget} \
        ${lib.escapeShellArg loopback.outputFallback}
'') managedLoopbackList}

      echo
      echo "unmanaged audio loopbacks:"
      unmanaged="$(
        {
          pw-dump | jq -r --argjson managed '${builtins.toJSON managedLoopbackNodeNames}' '
            [
              .[]
              | select(.type == "PipeWire:Interface:Node")
              | .info.props as $p
              | {
                  group: ($p."node.link-group" // $p."node.group" // ""),
                  name: ($p."node.name" // ""),
                  desc: ($p."node.description" // ""),
                  class: ($p."media.class" // "")
                }
              | select((.group | startswith("loopback-")) or (.name | test("loopback")))
            ]
            | sort_by(.group)
            | group_by(.group)[]
            | select((map(.name) | any(. as $name | $managed | index($name))) | not)
            | "  " + (.[0].group // "unknown"),
              (.[] | "    \(.name) [\(.class)] \(.desc)")
          '
        } 2>/dev/null || true
      )"

      if [ -z "$unmanaged" ]; then
        echo "  none"
      else
        echo "$unmanaged"
      fi
    '';
  };
in
{
  options.services.pipewire.audioRouting = {
    enable = lib.mkEnableOption "local PipeWire audio routing helpers";

    commands = {
      outputToggle = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-output-toggle";
        description = "Command that toggles the current input to current output loopback.";
      };

      cubiluxToggle = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-cubilux-toggle";
        description = "Command that toggles the current input to Cubilux loopback.";
      };

      rebind = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-rebind";
        description = "Command that restarts active managed loopbacks against current audio defaults.";
      };

      status = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-status";
        description = "Command that prints managed and unmanaged audio loopback status.";
      };
    };

    outputs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        "DAC" = "alsa_output.usb-JDS_Labs_JDS_Labs_Element_III-00.analog-stereo";
        "Cubilux" = "alsa_output.usb-Generic_USB_Audio-00.analog-stereo";
      };
      description = ''
        Display name to PipeWire runtime output name map. Attribute names are
        used by combined output definitions and command output.
      '';
    };

    combinedOutputs = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name for the generated virtual output.";
          };

          outputs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Display names from services.pipewire.audioRouting.outputs.";
          };
        };
      });
      default = [];
      description = "Virtual outputs that forward audio to multiple real outputs.";
    };

    outputLoopback = {
      service = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-output.service";
        description = "User systemd service name for current input to current output loopback.";
      };

      nodeName = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-output";
        description = "PipeWire node name for current input to current output loopback.";
      };

      route = lib.mkOption {
        type = lib.types.str;
        default = "current input -> current output";
        description = "Human-readable route label used in command status output.";
      };
    };

    cubiluxLoopback = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Start current input to Cubilux loopback by default in user sessions.";
      };

      output = lib.mkOption {
        type = lib.types.str;
        default = "Cubilux";
        description = "Display name of the output used by the Cubilux loopback.";
      };

      service = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-cubilux.service";
        description = "User systemd service name for current input to Cubilux loopback.";
      };

      nodeName = lib.mkOption {
        type = lib.types.str;
        default = "audio-loopback-cubilux";
        description = "PipeWire node name for current input to Cubilux loopback.";
      };

      route = lib.mkOption {
        type = lib.types.str;
        default = "current input -> Cubilux";
        description = "Human-readable route label used in command status output.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = missingOutputNames == [];
        message = ''
          services.pipewire.audioRouting references unknown outputs:
          ${lib.concatStringsSep ", " missingOutputNames}
        '';
      }
      {
        assertion = invalidCombinedOutputs == [];
        message = "services.pipewire.audioRouting.combinedOutputs entries must contain at least two outputs.";
      }
    ];

    services.pipewire.extraConfig.pipewire."20-combined-audio-outputs" = lib.mkIf (cfg.combinedOutputs != []) {
      "context.modules" = map mkCombinedAudioOutput cfg.combinedOutputs;
    };

    systemd.user.services = lib.listToAttrs (map (loopback:
      lib.nameValuePair (serviceName loopback.service) {
        description = "Loop ${loopback.route}";
        wantedBy = lib.mkIf loopback.startByDefault [ "default.target" ];
        after = [ "pipewire.service" "wireplumber.service" ];
        partOf = [ "pipewire.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.pipewire}/bin/pw-loopback --name ${loopback.nodeName} --capture @DEFAULT_AUDIO_SOURCE@ --playback ${loopback.outputTarget}";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      })
      managedLoopbackList);

    environment.systemPackages = [
      audioLoopbackOutputToggle
      audioLoopbackCubiluxToggle
      audioLoopbackRebind
      audioLoopbackStatus
    ];
  };
}
