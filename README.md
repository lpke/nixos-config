# nixos-config

My configuration for NixOS.

## Building

```bash
sudo nixos-rebuild switch --flake /etc/nixos#lpnix
```

## Location in dotfiles

The default location for these files is `/etc/nixos/`.

I prefer to keep this location with my other dotfiles, in `~/.config/nixos`.

To do this, I symlink the custom location back to the default system location:

```bash
sudo ln -s ~/.config/nixos /etc/nixos
```
