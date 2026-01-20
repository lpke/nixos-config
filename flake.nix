{
  description = "NixOS config with Home Manager";

  # External things the flake depends on
  # attribute set, where each key names a dependency, and is a flake of its own
  # gets resolved before being passed to `outputs`

  inputs = {
    # official NixOS package repository branches
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # pinned package version commits
    # to get commit versions: https://www.nixhub.io
    nixpkgs-neovim-pin.url = "github:NixOS/nixpkgs/f665af0cdb70ed27e1bd8f9fdfecaf451260fc55"; # 0.11.5 (Jan 2026)

    # user environment manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # key remapping tool
    xremap-flake = {
      url = "github:xremap/nix-flake";
    };
  };

  # What the flake produces
  # function, taking resolved `inputs` as an attribute set
  # returns an attribute set

  outputs = { nixpkgs, nixpkgs-unstable, nixpkgs-neovim-pin, home-manager, xremap-flake, ... }@inputs:
    let
      system = "x86_64-linux";
      # these will be made available in configuration.nix via specialArgs
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
      pkgs-neovim = nixpkgs-neovim-pin.legacyPackages.${system};
    in {
      nixosConfigurations = {
        lpnix = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit pkgs-unstable pkgs-neovim; };
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.luke = import ./home.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
      };
    };
}
