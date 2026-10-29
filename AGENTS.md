## Rules

- Keep `system/help/help.txt`, printed by the custom `help` command, as a concise reference for user-facing custom commands and aliases provided by this configuration. Update it when those features change, not for every package, script, or configuration edit. Use the `syslore` skill, if available, to keep the relevant Syslore records up to date alongside the help.
- Each entry should show an invocation and a short description of what it does. Point to a command's own help for detailed options. Keep implementation details, config paths, permission values, machine-specific identifiers, troubleshooting, and fix history in code comments or repository documentation instead.
- Put custom command implementations in their own file under `pkgs/<command>/` or a focused module, then surface them from `system/configuration.nix`; do not inline non-trivial command scripts in `configuration.nix`.
