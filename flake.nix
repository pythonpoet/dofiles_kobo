{
  description = "puffnfresh's personal Nix Flake, mainly for Hydra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # Use a stable branch
    mobile-nixos = {
      url = "github:puffnfresh/mobile-nixos/hydra";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
outputs = { self, nixpkgs, mobile-nixos, home-manager }:
    rec {
      nixosConfigurations = {
        termly =
          nixpkgs.lib.nixosSystem {
            system = "armv7l-linux";
            modules = [
              {
                nixpkgs.overlays = [
                  (final: prev: {
                    libgit2 = prev.libgit2.overrideAttrs (_: { doCheck = false; });
                    aws-c-common = prev.aws-c-common.overrideAttrs (_: { doCheck = false; });
                  })
                ];
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
