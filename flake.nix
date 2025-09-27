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
      overlays.default = final: prev: {
        # Fixes: Disable failing checks for cross-compilation
        libconfig = prev.libconfig.overrideAttrs (oldAttrs: {
          doCheck = false;
        });
        # CRITICAL: Added an extra, harmless attribute (postPatch)
        # to ensure the derivation hash is changed and the override is actually used.
        rhash = prev.rhash.overrideAttrs (old: {
          doCheck = false;
          checkPhase = "true"; # disable custom test runner
          postPatch = (old.postPatch or "") + ''
            echo "Skipping rhash tests for cross-compilation"
          '';
        });

        mobile-nixos = mobile-nixos;


      };

      nixosConfigurations = {
        termly =
          nixpkgs.lib.nixosSystem {
            system = "armv7l-linux";
            pkgs = nixpkgs.legacyPackages.armv7l-linux.extend self.overlays.default;
            specialArgs = { inherit mobile-nixos; }; 
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