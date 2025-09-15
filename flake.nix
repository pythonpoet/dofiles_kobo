{
  description = "puffnfresh's personal Nix Flake, mainly for Hydra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mobile-nixos = {
      url = "github:mobile-nixos/mobile-nixos";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, mobile-nixos, home-manager }:
  let
    # Add this block to enable cross-compilation and binary caches
    nixConfig = {
      extra-platforms = [ "armv7l-linux" ];
      extra-substituters = [
        "https://cache.nixos.org"
        "https://hydra.nixos.org"
      ];
      extra-trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hydra.nixos.org-1:E57lU8Q76ZypQ+A/exyz5Z9T8tQmNVpXgqLx71H0qcY="
      ];
    };
  in
    rec {
      nixosConfigurations = {
        termly =
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              {
                  nixpkgs.hostPlatform = "armv7l-linux";
                  nixpkgs.buildPlatform = "x86_64-linux";
                }
                          ./machines/kobo-clara-2e/configuration.nix
              (import "${mobile-nixos}/lib/configuration.nix" { device = "kobo-clara-2e"; })
              home-manager.nixosModules.home-manager
            ];
          };
        tectonic =
          nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = [
              ./machines/tectonic/configuration.nix
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