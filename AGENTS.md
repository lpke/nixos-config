## Rules

- Update the custom `help` command text when adding or changing custom commands. The help output should list actual commands only, not config notes or config file paths.
- Put custom command implementations in their own file under `pkgs/<command>/` or a focused module, then surface them from `system/configuration.nix`; do not inline non-trivial command scripts in `configuration.nix`.
