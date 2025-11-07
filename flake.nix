{
  description = "puffnfresh's personal Nix Flake, mainly for Hydra";

  inputs = {
    nixpkgs.url = "github:pythonpoet/nixpkgs/master"; # Use a stable branch
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
    {
      nixosConfigurations = {
        termly =
          nixpkgs.lib.nixosSystem {
            system = "armv7l-linux";
            modules = [
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
          toplevel = name: self.nixosConfigurations."${name}".config.system.build.toplevel;
        in
        {
          kobo-clara-2e = toplevel "termly";
          oci-compute-instance = toplevel "tectonic";
        };
    };
}
