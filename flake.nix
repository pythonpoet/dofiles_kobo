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
        # This overlay extends the previous package set (prev) with custom changes.
        # It adds a patched version of libconfig and the mobile-nixos project itself.
        libconfig = prev.libconfig.overrideAttrs (oldAttrs: {
          doCheck = false;
        });
        rhash = prev.rhash.overrideAttrs (oldAttrs: {
          doCheck = false;
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