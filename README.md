# nixos-config

My configuration for NixOS.

## Entrypoints

The root entrypoint file is `/flake.nix`.

System configuration starts with `/system/configuration.nix`

User configuration with home-manager starts with `/user/home.nix`

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

## Documentation

Detailed explanation of how NixOS config works when using flakes/home-manager:

https://www.notion.so/lpke/NixOS-Config-Explained-2eb1076d16c9806d9021e512329f9b53
