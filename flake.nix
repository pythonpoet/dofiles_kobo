{
  description = "puffnfresh's personal Nix Flake, mainly for Hydra";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            # Build on the ARM64 CI runner; mobile-nixos cross-compiles to armv7l
            # via nixpkgs.crossSystem (see mobile-nixos modules/system-target.nix).
            system = "aarch64-linux";
            modules = [
              {
                nixpkgs.overlays = [
                  (final: prev: {
                    libgit2 = prev.libgit2.overrideAttrs (_: { doCheck = false; });
                    aws-c-common = prev.aws-c-common.overrideAttrs (_: { doCheck = false; });
                    perlPackages = prev.perlPackages // {
                      Po4a = prev.perlPackages.Po4a.overrideAttrs (_: { doCheck = false; });
                    };

                    # Force OpenBLAS to use the generic ARMV6 codepath.
                    # This avoids kernel/arm/gemv_n_vfpv3.S which assumes
                    # 32 D-registers (vfpv3-d32), incompatible with how
                    # the assembler is invoked in this toolchain.
                    # ARMV6 path uses only d0-d15 and Fortran/LAPACK stay intact.
                    openblas = prev.openblas.overrideAttrs (old: {
                      makeFlags = (old.makeFlags or []) ++ [
                        "TARGET=ARMV6"
                        "DYNAMIC_ARCH=0"
                      ];
                      preBuild = (old.preBuild or "") + ''
                        export TARGET=ARMV6
                        export DYNAMIC_ARCH=0
                      '';
                      doCheck = false;
                    });
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