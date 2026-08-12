{ config, lib, pkgs, ... }:

let
  cfg = config.services.pipewire.audioRouting;
  devicesMap = config.services.pipewire.audioDevicesMap;
  mixedCapture = cfg.mixedCapture;

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
  mixedCaptureTargetSpecs = lib.optionals mixedCapture.enable [ mixedCapture.microphone mixedCapture.systemOutput ];

  invalidCombinedOutputs = lib.filterAttrs (_: output: output.enable && builtins.length output.outputs < 2) cfg.combinedOutputs.outputs;
  invalidCombinedDefaultTargets = lib.filter isDefaultTarget combinedOutputSpecs;
  invalidRawOutputTargets = invalidRawTargets (combinedOutputSpecs ++ loopbackTargetSpecs ++ mixedCaptureTargetSpecs);
  missingDeviceTargets = missingDeviceNames (combinedOutputSpecs ++ loopbackTargetSpecs ++ mixedCaptureTargetSpecs);

  enabledCombinedOutputs =
    if cfg.combinedOutputs.enable
    then lib.filterAttrs (_: output: output.enable) cfg.combinedOutputs.outputs
    else {};
  enabledLoopbacks =
    if cfg.loopbacks.enable
    then lib.filterAttrs (_: loopback: loopback.enable) cfg.loopbacks.items
    else {};

  mixedCaptureBusName = "${mixedCapture.nodeName}_bus";
  mixedCapturePulseCommands = [
    {
      cmd = "load-module";
      args = ''module-null-sink sink_name=${mixedCaptureBusName} sink_properties="device.description=Mixed-Capture-Bus node.pause-on-idle=true" rate=48000 channels=2 channel_map=front-left,front-right'';
      flags = [];
    }
    {
      cmd = "load-module";
      args = ''module-remap-source master=${mixedCaptureBusName}.monitor source_name=${mixedCapture.nodeName} source_properties="device.description=Mixed-Capture node.pause-on-idle=true" channels=2 channel_map=front-left,front-right master_channel_map=front-left,front-right'';
      flags = [];
    }
  ];

  noFallbackPlaybackProps = builtins.toJSON {
    "node.dont-fallback" = true;
    "node.linger" = true;
  };

  mixedCaptureSystemMonitorModule = {
    name = "libpipewire-module-loopback";
    args = {
      "node.description" = "${mixedCapture.description} system audio";
      "target.delay.sec" = mixedCapture.latencyMs / 1000.0;
      "capture.props" = {
        "node.name" = "input.${mixedCapture.nodeName}_system_audio";
        "node.passive" = true;
        "stream.capture.sink" = true;
      } // lib.optionalAttrs (!isDefaultSink mixedCapture.systemOutput) {
        "target.object" = resolveOutputTarget mixedCapture.systemOutput;
        "node.dont-fallback" = true;
        "node.linger" = true;
      };
      "playback.props" = {
        "node.name" = "output.${mixedCapture.nodeName}_system_audio";
        "target.object" = mixedCaptureBusName;
        "node.dont-fallback" = true;
        "node.linger" = true;
        "node.passive" = true;
      };
    };
  };

  mixedCaptureMicrophoneModule = {
    name = "libpipewire-module-loopback";
    args = {
      "node.description" = "${mixedCapture.description} microphone";
      "target.delay.sec" = mixedCapture.latencyMs / 1000.0;
      "capture.props" = {
        "node.name" = "input.${mixedCapture.nodeName}_microphone";
        "target.object" = resolveLoopbackTarget "@DEFAULT_AUDIO_SOURCE@" mixedCapture.microphone;
        "node.passive" = true;
      } // lib.optionalAttrs (!isDefaultSource mixedCapture.microphone) {
        "node.dont-fallback" = true;
        "node.linger" = true;
      };
      "playback.props" = {
        "node.name" = "output.${mixedCapture.nodeName}_microphone";
        "target.object" = mixedCaptureBusName;
        "node.dont-fallback" = true;
        "node.linger" = true;
        "node.passive" = true;
      };
    };
  };

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
        "node.pause-on-idle" = true;
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

    mixedCapture = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "mixed microphone and system-audio capture source";

          description = lib.mkOption {
            type = lib.types.str;
            default = "Mixed Capture";
            description = "Human-readable virtual input label used by audio status.";
          };

          nodeName = lib.mkOption {
            type = lib.types.strMatching "[A-Za-z0-9._]+";
            default = "mixed_capture";
            description = "PipeWire/Pulse source name exposed to recording applications.";
          };

          microphone = lib.mkOption {
            type = lib.types.str;
            default = "DEFAULT_SOURCE";
            description = "DEFAULT_SOURCE, friendly audioDevicesMap.pipewireNodes name, or RAW:<pipewire-node-name>.";
          };

          systemOutput = lib.mkOption {
            type = lib.types.str;
            default = "DEFAULT_SINK";
            description = "DEFAULT_SINK, friendly audioDevicesMap.pipewireNodes name, or RAW:<pipewire-sink-node-name> whose monitor should be captured.";
          };

          latencyMs = lib.mkOption {
            type = lib.types.ints.positive;
            default = 50;
            description = "Requested latency for each feed into the mixed capture bus.";
          };
        };
      };
      default = {};
      description = "Virtual input that mixes one microphone with one output monitor.";
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
      {
        assertion = !mixedCapture.enable || !isDefaultSink mixedCapture.microphone;
        message = "services.pipewire.audioRouting.mixedCapture.microphone cannot use DEFAULT_SINK.";
      }
      {
        assertion = !mixedCapture.enable || !isDefaultSource mixedCapture.systemOutput;
        message = "services.pipewire.audioRouting.mixedCapture.systemOutput cannot use DEFAULT_SOURCE.";
      }
    ];

    services.pipewire.extraConfig.pipewire."20-combined-audio-outputs" = lib.mkIf (enabledCombinedOutputs != {}) {
      "context.modules" = lib.mapAttrsToList mkCombinedAudioOutput enabledCombinedOutputs;
    };

    services.pipewire.extraConfig.pipewire-pulse."20-mixed-capture" = lib.mkIf mixedCapture.enable {
      "context.modules" = [
        mixedCaptureSystemMonitorModule
        mixedCaptureMicrophoneModule
      ];
      "pulse.cmd" = mixedCapturePulseCommands;
    };

    systemd.user.services = lib.mapAttrs' (id: loopback:
      lib.nameValuePair (serviceName loopback.service) {
        description = "Loop ${loopback.description}";
        wantedBy = lib.mkIf loopback.startByDefault [ "default.target" ];
        after = [ "pipewire.service" "wireplumber.service" ];
        partOf = [ "pipewire.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.pipewire}/bin/pw-loopback --name ${loopback.nodeName} --capture ${resolveLoopbackTarget "@DEFAULT_AUDIO_SOURCE@" loopback.input} --playback ${resolveLoopbackTarget "@DEFAULT_AUDIO_SINK@" loopback.output} --playback-props ${lib.escapeShellArg noFallbackPlaybackProps}";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      })
      enabledLoopbacks;
  };
}
