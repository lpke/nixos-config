{ config, lib, pkgs, ... }:

let
  cfg = config.services.localOllama;
  mode = if cfg.cuda.enable then "cuda" else "cpu";
in
{
  options.services.localOllama.cuda.enable =
    lib.mkEnableOption "CUDA-backed Ollama package";

  config = {
    services.ollama = {
      enable = true;
      package = if cfg.cuda.enable then pkgs.ollama-cuda else pkgs.ollama-cpu;
    };

    environment.etc."local-ollama/mode".text = "${mode}\n";

    system.nixos.tags = lib.optional cfg.cuda.enable "llm-cuda";
  };
}
