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
          cfg = self.nixosConfigurations.termly;
          targetPkgs = cfg.pkgs;
          # Root filesystem, built QEMU-free. make-ext4-fs (host-side
          # mkfs.ext4 -d) + extlinux populator + dd of u-boot — no runInLinuxVM,
          # which is broken for armv7l virtiofs/PCI (see below).
          rootfs = targetPkgs.callPackage "${nixpkgs}/nixos/lib/make-ext4-fs.nix" {
            storePaths = [ cfg.config.system.build.toplevel ];
            volumeLabel = "nixos";
            uuid = "44444444-4444-4444-8888-888888888888";
            populateImageCommands = ''
              mkdir -p ./files/boot
              ${cfg.config.boot.loader.generic-extlinux-compatible.populateCmd} \
                -c ${cfg.config.system.build.toplevel} -d ./files/boot
            '';
          };
        in
        targetPkgs.runCommand "termly.img" { nativeBuildInputs = [ targetPkgs.util-linux targetPkgs.dosfstools ]; } ''
          cp ${rootfs} rootfs.img
          # Single MBR partition (type 83) for the rootfs; u-boot dd'd at 1 KiB.
          img=$out
          truncate -s $((4096 + $(stat -c %s rootfs.img) + 1024*1024)) $img
          sfdisk --no-reread $img <<EOF
            label: dos
            unit: sectors
            start=2048, type=83, bootable
          EOF
          partx $img -o START -n 1
          dd if=rootfs.img of=$img seek=2048 conv=notrunc
          dd if=${self.packages.armv7l-linux.uBoot}/u-boot-dtb.imx of=$img bs=1k seek=1 conv=notrunc
        '';


      hydraJobs.kobo-clara-2e =
        self.nixosConfigurations.termly.config.system.build.toplevel;
    };
}
