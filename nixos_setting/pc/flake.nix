{
  description = "NixOS PC desktop and development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      lanzaboote,
      ...
    }:
    let
      mkSystem =
        extraModules:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hardware-configuration.nix
            ./configuration.nix
          ]
          ++ extraModules;
        };

      secureBootModules = [
        lanzaboote.nixosModules.lanzaboote
        ./secureboot.nix
      ];
    in
    {
      nixosConfigurations = {
        pc = mkSystem [ ];
        pc-nvidia = mkSystem [ ./nvidia.nix ];
        pc-nvidia-cuda = mkSystem [
          ./nvidia.nix
          ./cuda.nix
        ];

        pc-secureboot = mkSystem secureBootModules;
        pc-nvidia-secureboot = mkSystem ([ ./nvidia.nix ] ++ secureBootModules);
        pc-nvidia-cuda-secureboot = mkSystem (
          [
            ./nvidia.nix
            ./cuda.nix
          ]
          ++ secureBootModules
        );
      };
    };
}
