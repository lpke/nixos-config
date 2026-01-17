{
  description = "NixOS config with Home Manager";

  # External things the flake depends on
  # attribute set, where each key names a dependency, and is a flake of its own
  # gets resolved before being passed to `outputs`

  inputs = {
    # official NixOS package repository
    nixpkgs = {
      url = "nixpkgs/nixos-25.11";
    };

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

  outputs = { nixpkgs, home-manager, xremap-flake, ... }@inputs: {
    nixosConfigurations = {
      lpnix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
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
