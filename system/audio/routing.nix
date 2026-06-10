{ config, lib, pkgs, ... }:

let
  cfg = config.services.pipewire.audioRouting;
  devicesMap = config.services.pipewire.audioDevicesMap;

  rawPrefix = "RAW:";
  isRaw = value: lib.hasPrefix rawPrefix value;
  rawNode = value: lib.removePrefix rawPrefix value;
  isDefaultSource = value: builtins.elem value [ "DEFAULT_SOURCE" "@DEFAULT_AUDIO_SOURCE@" ];
  isDefaultSink = value: builtins.elem value [ "DEFAULT_SINK" "@DEFAULT_AUDIO_SINK@" ];
  isDefaultTarget = value: isDefaultSource value || isDefaultSink value;

  outputId = value:
    lib.toLower (builtins.replaceStrings
      [ " " "+" "-" "." "/" "(" ")" ]
      [ "_" "plus" "_" "_" "_" "" "" ]
      value);

  serviceName = service: lib.removeSuffix ".service" service;

  targetNeedsDevicesMap = value: !(isRaw value) && !(isDefaultTarget value);
  invalidRawTargets = values: lib.filter (value: isRaw value && rawNode value == "") values;
  missingDeviceNames = values:
    lib.unique (lib.filter
      (value: targetNeedsDevicesMap value && !(builtins.hasAttr value devicesMap.pipewireNodes))
      values);

  resolveOutputTarget = value:
    if isRaw value then rawNode value
    else devicesMap.pipewireNodes.${value};

  resolveLoopbackTarget = defaultTarget: value:
    if isRaw value then rawNode value
    else if isDefaultTarget value then defaultTarget
    else devicesMap.pipewireNodes.${value};

  combinedOutputSpecs = lib.concatMap (output: output.outputs) (lib.attrValues cfg.combinedOutputs.outputs);
  loopbackTargetSpecs = lib.concatMap (loopback: [ loopback.input loopback.output ]) (lib.attrValues cfg.loopbacks.items);

  invalidCombinedOutputs = lib.filterAttrs (_: output: output.enable && builtins.length output.outputs < 2) cfg.combinedOutputs.outputs;
  invalidCombinedDefaultTargets = lib.filter isDefaultTarget combinedOutputSpecs;
  invalidRawOutputTargets = invalidRawTargets (combinedOutputSpecs ++ loopbackTargetSpecs);
  missingDeviceTargets = missingDeviceNames (combinedOutputSpecs ++ loopbackTargetSpecs);

  enabledCombinedOutputs =
    if cfg.combinedOutputs.enable
    then lib.filterAttrs (_: output: output.enable) cfg.combinedOutputs.outputs
    else {};
  enabledLoopbacks =
    if cfg.loopbacks.enable
    then lib.filterAttrs (_: loopback: loopback.enable) cfg.loopbacks.items
    else {};

  mkCombinedAudioOutput = id: combinedOutput: {
    name = "libpipewire-module-combine-stream";
    args = {
      "combine.mode" = "sink";
      "node.name" = "combined_${outputId id}";
      "node.description" = combinedOutput.description;
      "node.nick" = combinedOutput.description;
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
            "node.name" = resolveOutputTarget output;
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
in
{
  options.services.pipewire.audioRouting = {
    enable = lib.mkEnableOption "local PipeWire audio routing helpers";

    combinedOutputs = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable combined output creation.";
          };

          outputs = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Create this combined output.";
                };

                description = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Display name for the generated virtual output.";
                };

                outputs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Friendly audioDevicesMap.pipewireNodes names, or RAW:<pipewire-node-name> for raw PipeWire node names.";
                };
              };
            }));
            default = {};
            description = "Configured combined outputs.";
          };
        };
      };
      default = {
        enable = false;
        outputs = {};
      };
      description = "Virtual outputs that forward audio to multiple real outputs.";
    };

    loopbacks = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable managed loopback services.";
          };

          items = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Create this managed loopback service.";
                };

                startByDefault = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Start this loopback by default in user sessions.";
                };

                description = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Human-readable loopback route label.";
                };

                input = lib.mkOption {
                  type = lib.types.str;
                  default = "DEFAULT_SOURCE";
                  description = "DEFAULT_SOURCE, friendly audioDevicesMap.pipewireNodes name, or RAW:<pipewire-node-name>.";
                };

                output = lib.mkOption {
                  type = lib.types.str;
                  description = "DEFAULT_SINK, friendly audioDevicesMap.pipewireNodes name, or RAW:<pipewire-node-name>.";
                };

                service = lib.mkOption {
                  type = lib.types.str;
                  default = "audio-loopback-${name}.service";
                  description = "User systemd service name.";
                };

                nodeName = lib.mkOption {
                  type = lib.types.str;
                  default = "audio-loopback-${name}";
                  description = "PipeWire node name.";
                };
              };
            }));
            default = {};
            description = "Configured managed loopbacks.";
          };
        };
      };
      default = {
        enable = false;
        items = {};
      };
      description = "Managed PipeWire loopbacks.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = missingDeviceTargets == [];
        message = ''
          services.pipewire.audioRouting references unknown friendly devices:
          ${lib.concatStringsSep ", " missingDeviceTargets}
        '';
      }
      {
        assertion = invalidRawOutputTargets == [];
        message = "services.pipewire.audioRouting RAW: targets must include a non-empty PipeWire node name.";
      }
      {
        assertion = invalidCombinedOutputs == {};
        message = "services.pipewire.audioRouting.combinedOutputs entries must contain at least two outputs.";
      }
      {
        assertion = invalidCombinedDefaultTargets == [];
        message = "services.pipewire.audioRouting.combinedOutputs cannot use DEFAULT_SOURCE or DEFAULT_SINK targets.";
      }
    ];

    services.pipewire.extraConfig.pipewire."20-combined-audio-outputs" = lib.mkIf (enabledCombinedOutputs != {}) {
      "context.modules" = lib.mapAttrsToList mkCombinedAudioOutput enabledCombinedOutputs;
    };

    systemd.user.services = lib.mapAttrs' (id: loopback:
      lib.nameValuePair (serviceName loopback.service) {
        description = "Loop ${loopback.description}";
        wantedBy = lib.mkIf loopback.startByDefault [ "default.target" ];
        after = [ "pipewire.service" "wireplumber.service" ];
        partOf = [ "pipewire.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.pipewire}/bin/pw-loopback --name ${loopback.nodeName} --capture ${resolveLoopbackTarget "@DEFAULT_AUDIO_SOURCE@" loopback.input} --playback ${resolveLoopbackTarget "@DEFAULT_AUDIO_SINK@" loopback.output}";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      })
      enabledLoopbacks;
  };
}
