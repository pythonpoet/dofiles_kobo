{
  description = "Kobo Clara 2E (termly) NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      crossPkgs = import nixpkgs {
        system = "x86_64-linux";
        crossSystem = nixpkgs.lib.systems.examples.armv7l-hf-multiplatform;
      };
    in {
      nixosConfigurations.termly = nixpkgs.lib.nixosSystem {
        system = "armv7l-linux";
        modules = [
          {
            nixpkgs.buildPlatform = "x86_64-linux";
            nixpkgs.hostPlatform = "armv7l-linux";
            # Add the overlay here
            nixpkgs.overlays = [
              (final: prev: {
                libqmi = prev.libqmi.overrideAttrs (old: {
                  depsBuildBuild = (old.depsBuildBuild or []) ++ [ final.pkgsBuildBuild.pkg-config ];
                });
                makeModulesClosure = args:
                      prev.makeModulesClosure (args // { allowMissing = true; });
                # vmTools spins up a QEMU VM off-host (via make-disk-image) to build
                # the SD image. The virtiofsd daemon it launches runs on the build
                # HOST (like qemu itself), so it must be built for the build
                # platform — the target-armv7l virtiofsd fails because vm-memory 0.16
                # vmTools spins up a QEMU VM off-host (via make-disk-image) to build
                # the SD image. The virtiofsd daemon it launches runs on the build
                # HOST (like qemu itself), so it must be built for the build
                # platform — the target-armv7l virtiofsd fails because vm-memory 0.16
                # only supports 64-bit targets.
                vmTools = prev.vmTools.override {
                  virtiofsd = final.buildPackages.virtiofsd;
                  # vmTools binds `qemu = buildPackages.qemu_kvm`, which on an x86
                  # host ships only qemu-system-i386/x86_64. Our guest is armv7l,
                  # so `qemu-common.qemuBinary` resolves to qemu-system-arm, which
                  # qemu_kvm does not contain (exit 127). Use the full QEMU build
                  # (all softmmu targets incl. arm) so the arm guest can be
                  # TCG-emulated; x86 KVM can't accelerate an armv7 guest anyway.
                  customQemu = "${final.buildPackages.qemu}/bin/qemu-system-arm -machine virt,accel=kvm:tcg -cpu max";
                };
              })
            ];
          }
          ./configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };

      packages.aarch64-linux.kernel =
        crossPkgs.callPackage ./pkgs/linux-clara2e.nix {};

      packages.aarch64-linux.uBoot =
        crossPkgs.callPackage ./pkgs/u-boot-clara2e.nix {};

      packages.x86_64-linux.kernel =
        crossPkgs.callPackage ./pkgs/linux-clara2e.nix {};

      packages.x86_64-linux.uBoot =
        crossPkgs.callPackage ./pkgs/u-boot-clara2e.nix {};

      packages.armv7l-linux.uBoot =
        self.nixosConfigurations.termly.pkgs.callPackage ./pkgs/u-boot-clara2e.nix {};

      packages.armv7l-linux.image =
        let
          targetPkgs = self.nixosConfigurations.termly.pkgs;
          rootfs = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
            inherit (self.nixosConfigurations.termly) config;
            inherit (nixpkgs) lib;
            pkgs = targetPkgs;
            partitionTableType = "legacy";
            format = "raw";
            diskSize = "auto";
            additionalSpace = "1024M";
          };
        in targetPkgs.runCommand "termly.img" {} ''
          cp ${rootfs}/nixos.img $out
          chmod +w $out
          dd if=${self.packages.armv7l-linux.uBoot}/u-boot.imx \
             of=$out bs=1k seek=1 conv=notrunc
        '';

      hydraJobs.kobo-clara-2e =
        self.nixosConfigurations.termly.config.system.build.toplevel;
    };
}
