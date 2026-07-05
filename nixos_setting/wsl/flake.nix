{
  description = "Reproducible, development-only NixOS-WSL environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixos-wsl,
      ...
    }:
    let
      mkSystem =
        extraModules:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            ./configuration.nix
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        nixos-wsl = mkSystem [ ];
        nixos-wsl-cuda = mkSystem [ ./cuda.nix ];
      };
    };
}
