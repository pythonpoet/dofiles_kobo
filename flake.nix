{
  description = "A Nix Flake for various devices, including a Kobo Clara 2E build job.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mobile-nixos.url = "github:NixOS/mobile-nixos";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
   self, nixpkgs, mobile-nixos, home-manager
   }:let
       # Define the target system for the Kobo buildtargetSystem = "armv7l-linux";
       # # Define the host system where the build is runninghostSystem = builtins.currentSystem;
       # # Import the host's Nixpkgs for build-time tools
       hostSystem = "aarch64-linux";
       targetSystem = "armv7l-linux";
  pkgs-buildHost = import nixpkgs {
    inherit hostSystem;
    overlays = [ mobile-nixos.overlay ];
  };
in
rec {
  nixosConfigurations = {
    kobo-clara-2e =
      nixpkgs.lib.nixosSystem {
        # Build on the host system, but with cross-compilation configured.
        system = hostSystem;
        
        # Pass arguments to the modules
        specialArgs = {
          # This pkgs is for the target system (Kobo)
          pkgs = import nixpkgs {
            inherit targetSystem;
            crossSystem = {
              system = targetSystem;
              # The host system where the build will happen.
              # This is crucial for finding build tools like mobile-nixos.
              build = hostSystem;
            };
            overlays = [ mobile-nixos.overlay ];
          };
          # This pkgs-buildHost is for tools that must run on the host.
          inherit pkgs-buildHost;
        };
        
        modules = [
          # The device configuration
          ./machines/kobo-clara-2e/configuration.nix
          # The Mobile NixOS module
          (import "${mobile-nixos}/lib/configuration.nix" { device = "kobo-clara-2e"; })
          # Home Manager module
          home-manager.nixosModules.home-manager
        ];
      };
    
    # ... other configurations if needed ...
  };

  hydraJobs =
    let
      toplevel = name: nixosConfigurations."${name}".config.system.build.toplevel;
    in
    {
      kobo-clara-2e = toplevel "kobo-clara-2e";
    };

};
}
