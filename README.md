# nixos-config

My configuration for NixOS.

## Location in dotfiles

The default location for these files is `/etc/nixos/`.

I prefer to keep this location with my other dotfiles, in `~/.config/nixos`.

To do this, I can sym link the new location back to the default system location, but I find adding this to my shell to be simpler:

```bash
export NIX_PATH="nixos-config=~/.config/nixos/configuration.nix"
```
