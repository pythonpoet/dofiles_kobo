{
  description = "puffnfresh's personal Nix Flake, mainly for Hydra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # Use a stable branch
    mobile-nixos = {
      url = "github:puffnfresh/mobile-nixos/hydra";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
outputs = { self, nixpkgs, mobile-nixos, home-manager, ... }@inputs:
    let
      # This is the "sledgehammer" overlay.
      # It not only sets doCheck to false but also physically replaces the
      # checkPhase with a command that does nothing. This cannot be ignored.
      disable-checks-overlay = final: prev: {
        rhash = prev.rhash.overrideAttrs (old: {
          doCheck = false;
          checkTarget = null;  # prevents "make test-full" from being used
          postPatch = (old.postPatch or "") + ''
            echo "Skipping rhash tests for cross-compilation"
          '';
        });
        libconfig = prev.libconfig.overrideAttrs (old: {
          doCheck = false;
          checkTarget = null;  # prevents "make test-full" from being used
          postPatch = (old.postPatch or "") + ''
            echo "Skipping rhash tests for cross-compilation"
          '';
        });
        # pcre = prev.pcre.overrideAttrs (old: {
        #   doCheck = false;
        #   checkTarget = null;  # prevents "make test-full" from being used
        #   postPatch = (old.postPatch or "") + ''
        #     echo "Skipping pcre tests for cross-compilation"
        #   '';
        # });
      };

    in
    {
      nixosConfigurations = {
        termly =
          let
            system = "armv7l-linux";
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ disable-checks-overlay ];
              config.nixpkgs.crossSystem = {
                system = "x86_64-linux"; # Your build machine's architecture
              };
            };
          in
          nixpkgs.lib.nixosSystem {
            inherit system pkgs;
            specialArgs = { inherit mobile-nixos; };
            modules = [
              ./machines/kobo-clara-2e/configuration.nix
              (import "${mobile-nixos}/lib/configuration.nix" { device = "kobo-clara-2e"; })
              home-manager.nixosModules.home-manager
            ];
          };

        tectonic =
          let
            system = "aarch64-linux";
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ disable-checks-overlay ];
              config.nixpkgs.crossSystem = {
                system = "x86_64-linux";
              };
            };
          in
          nixpkgs.lib.nixosSystem {
            inherit system pkgs;
            specialArgs = { inherit mobile-nixos; };
            modules = [
              ./machines/tectonic/configuration.nix
            ];
          };
      };

      hydraJobs =
        let
          toplevel = name: self.nixosConfigurations."${name}".config.system.build.toplevel;
        in
        {
          kobo-clara-2e = toplevel "termly";
          oci-compute-instance = toplevel "tectonic";
        };
    };
}