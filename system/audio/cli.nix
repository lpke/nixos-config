{ config, lib, pkgs, ... }:

let
  devicesMap = config.services.pipewire.audioDevicesMap;
  routing = config.services.pipewire.audioRouting;
  locks = config.services.pipewire.audioVolumeLocks;
  gains = config.services.pipewire.audioGains;

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

  resolveLoopbackTarget = defaultTarget: value:
    if isRaw value then rawNode value
    else if isDefaultTarget value then defaultTarget
    else devicesMap.pipewireNodes.${value};

  resolveDeviceTarget = value:
    if isRaw value then rawNode value
    else devicesMap.pipewireNodes.${value};

  routingConfig = pkgs.writeText "audio-routing.json" (builtins.toJSON {
    enable = routing.enable;
    devicesMap = devicesMap.pipewireNodes;
    mixedCapture = {
      inherit (routing.mixedCapture) enable description nodeName microphone systemOutput latencyMs;
      busNodeName = "${routing.mixedCapture.nodeName}_bus";
      microphoneTarget = resolveLoopbackTarget "@DEFAULT_AUDIO_SOURCE@" routing.mixedCapture.microphone;
      systemOutputTarget = resolveLoopbackTarget "@DEFAULT_AUDIO_SINK@" routing.mixedCapture.systemOutput;
    };
    combinedOutputs = lib.mapAttrs (id: output: {
      inherit (output) enable description outputs;
      nodeName = "combined_${outputId id}";
      outputTargets = map (target:
        resolveDeviceTarget target
      ) output.outputs;
    }) routing.combinedOutputs.outputs;
    loopbacks = lib.mapAttrs (_: loopback: {
      inherit (loopback) enable startByDefault description input output service nodeName;
      inputTarget = resolveLoopbackTarget "@DEFAULT_AUDIO_SOURCE@" loopback.input;
      outputTarget = resolveLoopbackTarget "@DEFAULT_AUDIO_SINK@" loopback.output;
    }) routing.loopbacks.items;
  });

  mixedCaptureRestartToken = pkgs.writeText "mixed-capture-restart-token" (builtins.toJSON {
    inherit (routing.mixedCapture) enable nodeName microphone systemOutput latencyMs;
    microphoneTarget = resolveLoopbackTarget "@DEFAULT_AUDIO_SOURCE@" routing.mixedCapture.microphone;
    systemOutputTarget = resolveLoopbackTarget "@DEFAULT_AUDIO_SINK@" routing.mixedCapture.systemOutput;
    pulseConfig = config.services.pipewire.extraConfig.pipewire-pulse."20-mixed-capture" or {};
  });

  locksConfig = pkgs.writeText "audio-locks.json" (builtins.toJSON {
    inherit (locks) enable intervalSeconds service;
    locks = lib.mapAttrs (_: lock: lock // {
      nodeTarget =
        if isRaw lock.nodeName
        then rawNode lock.nodeName
        else devicesMap.pipewireNodes.${lock.nodeName};
    }) locks.locks;
  });

  gainsConfig = pkgs.writeText "audio-gains.json" (builtins.toJSON {
    inherit (gains) enable intervalSeconds service;
    gains = lib.mapAttrs (_: gain: gain // {
      cardTarget = gain.card;
    }) gains.gains;
  });

  audioCommand = pkgs.writeShellApplication {
    name = "audio";
    runtimeInputs = with pkgs; [
      alsa-utils
      coreutils
      gawk
      gnugrep
      gnused
      jq
      pipewire
      procps
      pulseaudio
      systemd
      wireplumber
    ];
    text = ''
      export AUDIO_ROUTING_CONFIG=${routingConfig}
      export AUDIO_LOCKS_CONFIG=${locksConfig}
      export AUDIO_GAINS_CONFIG=${gainsConfig}

    '' + builtins.readFile ./audio.sh;
  };

  arsCommand = pkgs.writeShellApplication {
    name = "ars";
    runtimeInputs = [ audioCommand ];
    text = ''
      exec audio restart "$@"
    '';
  };
in
{
  config = {
    environment.systemPackages = [
      audioCommand
      arsCommand
    ];

    systemd.user.services.${serviceName locks.service} = lib.mkIf locks.enable {
      description = "Force configured PipeWire input/output volumes";
      wantedBy = [ "default.target" ];
      after = [ "pipewire.service" "wireplumber.service" ];
      partOf = [ "pipewire.service" ];
      restartIfChanged = true;
      serviceConfig = {
        ExecStart = "${audioCommand}/bin/audio locks watch";
        Restart = "always";
        RestartSec = "1s";
      };
    };

    systemd.user.services.${serviceName gains.service} = lib.mkIf gains.enable {
      description = "Apply configured ALSA hardware gain targets";
      wantedBy = [ "default.target" ];
      after = [ "pipewire.service" "wireplumber.service" ];
      partOf = [ "pipewire.service" ];
      restartIfChanged = true;
      serviceConfig = {
        ExecStart = "${audioCommand}/bin/audio gain watch";
        Restart = "always";
        RestartSec = "1s";
      };
    };

    system.userActivationScripts.audioCustomServices = {
      deps = [];
      text = ''
        mixed_capture_state_dir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
        mixed_capture_state="$mixed_capture_state_dir/audio-mixed-capture-config"
        if ! ${pkgs.diffutils}/bin/cmp -s ${mixedCaptureRestartToken} "$mixed_capture_state"; then
          ${pkgs.systemd}/bin/systemctl --user try-restart pipewire-pulse.service 2>/dev/null || true
          ${pkgs.procps}/bin/pkill -TERM -u "$(${pkgs.coreutils}/bin/id -u)" -f -- '--utility-sub-type=audio.mojom.AudioService' 2>/dev/null || true
          ${pkgs.coreutils}/bin/install -Dm600 ${mixedCaptureRestartToken} "$mixed_capture_state"
        fi

        ${pkgs.systemd}/bin/systemctl --user stop audio-volume-lock.service nzxt-mic-gain-startup.service 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl --user reset-failed audio-volume-lock.service nzxt-mic-gain-startup.service 2>/dev/null || true

        ${lib.optionalString locks.enable ''
          ${pkgs.systemd}/bin/systemctl --user reset-failed ${lib.escapeShellArg locks.service} 2>/dev/null || true
          ${pkgs.systemd}/bin/systemctl --user restart ${lib.escapeShellArg locks.service} 2>/dev/null || true
        ''}
        ${lib.optionalString gains.enable ''
          ${pkgs.systemd}/bin/systemctl --user reset-failed ${lib.escapeShellArg gains.service} 2>/dev/null || true
          ${pkgs.systemd}/bin/systemctl --user restart ${lib.escapeShellArg gains.service} 2>/dev/null || true
        ''}
      '';
    };
  };
}
