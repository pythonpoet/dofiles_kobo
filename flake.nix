{
  description = "A Nix Flake for various devices, including a Kobo Clara 2E build job.";
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
  let
    # Define systems - use explicit strings instead of builtins.currentSystem
    hostSystem = "aarch64-linux";  # or "x86_64-linux" depending on your build machine
    targetSystem = "armv7l-linux";
    
    # Helper function to create packages for different systems
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
  in
  {
    nixosConfigurations.kobo-clara-2e = nixpkgs.lib.nixosSystem {
      system = hostSystem;
      
      specialArgs = {
        # Target system packages (for the Kobo)
        pkgs = import nixpkgs {
          system = targetSystem;
          crossSystem = {
            config = "armv7l-unknown-linux-gnueabihf";
            # Build system configuration
            linux-kernel = {
              name = "kobo";
              target = "zImage";
              autoModules = false;
              extraConfig = ''
                EMBEDDED y
                EXPERT y
              '';
            };
          };
          overlays = [ (import "${mobile-nixos}/overlay/overlay.nix") ];
        };
        
        # Build host packages (tools that run on the build machine)
        pkgs-buildHost = import nixpkgs {
          system = hostSystem;
          overlays = [ (import "${mobile-nixos}/overlay/overlay.nix") ];
        };
      };
      
      modules = [
        ./machines/kobo-clara-2e/configuration.nix
        (import "${mobile-nixos}/lib/configuration.nix" { device = "kobo-clara-2e"; })
        home-manager.nixosModules.home-manager
        
        # Add this module to handle the pkgs specialArgs properly
        ({ pkgs, ... }: {
          _module.args = {
            inherit pkgs;
          };
          nixpkgs.pkgs = pkgs;
        })
      ];
    };

    hydraJobs = {
      kobo-clara-2e = self.nixosConfigurations.kobo-clara-2e.config.system.build.toplevel;
    };

    # Optional: define packages for easier building
    packages = forAllSystems (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        kobo-image = self.nixosConfigurations.kobo-clara-2e.config.system.build.toplevel;
      }
    );

    # Default package for convenience
    defaultPackage = forAllSystems (system: self.packages.${system}.kobo-image);
  };
}
