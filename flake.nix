# ══════════════════════════════════════════════════════════════════
# NIXOS CONFIG ENTRYPOINT: It all starts here!
# ══════════════════════════════════════════════════════════════════

{
  description = "NixOS config with Home Manager";

  # External things the flake depends on
  # attribute set, where each key names a dependency, and is a flake of its own
  # gets resolved before being passed to `outputs`

  inputs = {
    # official NixOS package repository branches
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # user environment manager
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # KDE Plasma 6 DE config manager
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # key remapping tool
    xremap-flake = {
      url = "github:xremap/nix-flake";
    };
  };

  # What the flake produces
  # function, taking resolved `inputs` as an attribute set
  # returns an attribute set

  outputs = inputs@{
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    plasma-manager,
    xremap-flake,
    ...
    }:
    let
      system = "x86_64-linux";
      # these will be made available in configuration.nix via specialArgs
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
      mkLpnix = extraModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable; };
        modules = [
          # base config
          ./system/configuration.nix
          # enable home manager
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.luke = import ./user/home.nix;
            # pass `inputs` to `home.nix` for access to modules like `xremap-flake`
            home-manager.extraSpecialArgs = { inherit inputs; };
            # modules enabled for all users
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
          }
        ] ++ extraModules;
      };
    in {
      packages.${system}.adobe-photoshop = nixpkgs.legacyPackages.${system}.callPackage
        ./pkgs/adobe-photoshop {
          pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        };

      nixosConfigurations = {
        lpnix = mkLpnix [];

        lpnix-llm-cuda = mkLpnix [
          { services.localOllama.cuda.enable = true; }
        ];
      };
    };
}
