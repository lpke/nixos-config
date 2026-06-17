{
  pkgs,
  flakePath ? "/etc/nixos",
  baseConfig ? "lpnix",
  cudaConfig ? "lpnix-llm-cuda",
}:

pkgs.writeShellApplication {
  name = "bnix";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.nix
    pkgs.nixos-rebuild
    pkgs.systemd
  ];

  text = ''
    set -euo pipefail

    flake="''${NIXOS_CONFIG_FLAKE:-${flakePath}}"
    base_config="''${NIXOS_BASE_CONFIG:-${baseConfig}}"
    cuda_config="''${NIXOS_CUDA_CONFIG:-${cudaConfig}}"
    mode_file="/etc/local-ollama/mode"
    sudo_cmd="/run/wrappers/bin/sudo"
    mode="auto"
    action="switch"
    rebuild_args=()

    usage() {
      cat <<'EOF'
bnix [command] [nixos-rebuild args...]

Commands:
  bnix          Guarded rebuild: CUDA when ready, CPU fallback when not.
  bnix status   Show current Ollama mode, service status, and CUDA readiness.
  bnix cpu      Rebuild CPU Ollama config. Alias: --cpu.
  bnix cuda     Rebuild CUDA Ollama config without readiness prompt. Alias: --cuda.
  bnix help     Show this help.
EOF
    }

    require_flake() {
      if [ ! -f "$flake/flake.nix" ]; then
        echo "Missing flake: $flake/flake.nix" >&2
        echo "Set NIXOS_CONFIG_FLAKE to the config checkout path." >&2
        exit 1
      fi
    }

    require_sudo() {
      if [ ! -x "$sudo_cmd" ]; then
        echo "Missing sudo wrapper: $sudo_cmd" >&2
        exit 1
      fi
    }

    collect_local_builds() {
      local plan_file="$1"
      local builds_file="$2"

      grep -Eo '/nix/store/[^[:space:]]+\.drv' "$plan_file" | sort -u > "$builds_file" || true
    }

    current_ollama_mode() {
      if [ -r "$mode_file" ]; then
        tr -d '\n' < "$mode_file"
      else
        echo "unknown"
      fi
    }

    print_build_summary() {
      local builds_file="$1"
      local count

      count="$(wc -l < "$builds_file" | tr -d ' ')"
      sed -E 's|^/nix/store/[0-9a-z]+-||; s|\.drv$||' "$builds_file" | head -20 | sed 's/^/  /'

      if [ "$count" -gt 20 ]; then
        echo "  ...and $((count - 20)) more"
      fi
    }

    cuda_ollama_needs_local_build() {
      local plan_file="$1"
      local builds_file="$2"
      local cuda_attr

      cuda_attr="$flake#nixosConfigurations.$cuda_config.pkgs.ollama-cuda"

      if ! nix build --dry-run --no-link "$cuda_attr" > "$plan_file" 2>&1; then
        cat "$plan_file" >&2
        exit 1
      fi

      collect_local_builds "$plan_file" "$builds_file"
      [ -s "$builds_file" ]
    }

    choose_target() {
      local tmp_dir
      local plan_file
      local builds_file
      local reply
      local selected

      case "$mode" in
        cpu)
          echo "Selected mode: cpu" >&2
          echo "$base_config"
          return
          ;;
        cuda)
          echo "Selected mode: cuda" >&2
          echo "$cuda_config"
          return
          ;;
      esac

      tmp_dir="$(mktemp -d)"
      plan_file="$tmp_dir/cuda-ollama-dry-run.txt"
      builds_file="$tmp_dir/cuda-ollama-builds.txt"

      if cuda_ollama_needs_local_build "$plan_file" "$builds_file"; then
        echo >&2
        echo "CUDA Ollama is not already built or available from configured binary caches." >&2
        echo "Nix dry-run says these derivations would be built locally:" >&2
        print_build_summary "$builds_file" >&2
        echo >&2
        echo "This may take a long time and can make rebuilds noisy." >&2

        if [ ! -t 0 ]; then
          echo "No interactive terminal; using $base_config." >&2
          selected="$base_config"
        else
          printf 'Build CUDA Ollama anyway? [y/N] ' >&2
          if ! read -r reply; then
            reply=""
          fi

          case "$reply" in
            y|Y|yes|YES)
              selected="$cuda_config"
              ;;
            *)
              selected="$base_config"
              ;;
          esac
        fi
      else
        echo "CUDA Ollama is already built or available from binary cache." >&2
        selected="$cuda_config"
      fi

      rm -rf "$tmp_dir"
      case "$selected" in
        "$cuda_config")
          echo "Selected mode: cuda" >&2
          ;;
        *)
          echo "Selected mode: cpu" >&2
          ;;
      esac
      echo "$selected"
    }

    show_cuda_readiness() {
      local tmp_dir
      local plan_file
      local builds_file

      tmp_dir="$(mktemp -d)"
      plan_file="$tmp_dir/cuda-ollama-dry-run.txt"
      builds_file="$tmp_dir/cuda-ollama-builds.txt"

      echo "Checking CUDA Ollama build plan with nix dry-run..."

      if cuda_ollama_needs_local_build "$plan_file" "$builds_file"; then
        echo
        echo "Status: not ready"
        echo "CUDA Ollama is not already built or available from configured binary caches."
        echo "Nix dry-run says these derivations would be built locally:"
        print_build_summary "$builds_file"
        rm -rf "$tmp_dir"
        return 0
      fi

      echo
      echo "Status: ready"
      echo "CUDA Ollama is already built or available from configured binary caches."
      rm -rf "$tmp_dir"
    }

    show_status() {
      local mode
      local active
      local enabled

      mode="$(current_ollama_mode)"
      echo "Current mode: $mode"

      case "$mode" in
        cuda)
          echo "Ollama package: pkgs.ollama-cuda"
          echo "Rebuild target: $cuda_config"
          ;;
        cpu)
          echo "Ollama package: pkgs.ollama-cpu"
          echo "Rebuild target: $base_config"
          ;;
        *)
          echo "Ollama package: unknown"
          echo "Mode file: $mode_file"
          ;;
      esac

      if systemctl list-unit-files ollama.service >/dev/null 2>&1; then
        active="$(systemctl is-active ollama.service || true)"
        enabled="$(systemctl is-enabled ollama.service || true)"
        echo "ollama.service: $active ($enabled)"
      fi

      echo
      show_cuda_readiness
    }

    run_switch() {
      local target="$1"

      require_sudo

      exec "$sudo_cmd" nixos-rebuild switch --flake "$flake#$target" "''${rebuild_args[@]}"
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        status)
          action="status"
          shift
          ;;
        cpu)
          mode="cpu"
          shift
          ;;
        cuda)
          mode="cuda"
          shift
          ;;
        --cpu)
          mode="cpu"
          shift
          ;;
        --cuda)
          mode="cuda"
          shift
          ;;
        help|--help|-h)
          usage
          exit 0
          ;;
        --)
          shift
          while [ "$#" -gt 0 ]; do
            rebuild_args+=("$1")
            shift
          done
          ;;
        *)
          rebuild_args+=("$1")
          shift
          ;;
      esac
    done

    if [ "$action" = "status" ]; then
      require_flake
      show_status
      exit 0
    fi

    require_flake
    target="$(choose_target)"
    run_switch "$target"
  '';
}
