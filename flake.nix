{
  description = "puffnfresh's personal Nix Flake, mainly for Hydra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mobile-nixos = {
      url = "github:pythonpoet/mobile-nixos/main";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, mobile-nixos, home-manager }:
    rec {
      overlays.disable-libconfig-check = import ./disable-libconfig-check.nix;
      nixosConfigurations = {
        termly =
          nixpkgs.lib.nixosSystem {
            system = "armv7l-linux";
             overlays = [ self.overlays.disable-libconfig-check ];
            modules = [
              ./machines/kobo-clara-2e/configuration.nix
              (import "${mobile-nixos}/lib/configuration.nix" { device = "kobo-clara-2e"; })
              home-manager.nixosModules.home-manager
            ];
          };
      };

      hydraJobs =
        let
          toplevel =
            name: nixosConfigurations."${name}".config.system.build.toplevel;
        in
        {
          kobo-clara-2e = toplevel "termly";
          oci-compute-instance = toplevel "tectonic";
        };
    };
}