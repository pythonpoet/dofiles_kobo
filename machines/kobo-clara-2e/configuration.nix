{ pkgs, config, lib, ... }:

let
  uBootClara2e = pkgs.callPackage ./pkgs/u-boot-clara2e.nix {};
  linuxClara2e = pkgs.callPackage ./pkgs/linux-clara2e.nix {};
  firmwareClara2e = pkgs.callPackage ./pkgs/firmware-clara2e.nix {};
in
{
  # home-manager.users.brian = import ./home.nix;

  boot.kernelPackages = pkgs.linuxPackagesFor linuxClara2e;
  hardware.firmware = [ firmwareClara2e ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkForce true;

  system.build.uBoot = uBootClara2e;

  networking.hostName = "termly";
  networking.hostId = "0c5cb919";
  networking.interfaces.usb0.useDHCP = true;
  networking.nameservers = [ "1.1.1.1" ];

  zramSwap.enable = true;
  boot.kernel.sysctl."vm.swappiness" = 100;

  documentation.enable = false;
  systemd.coredump.enable = false;
  services.udisks2.enable = false;
  services.accounts-daemon.enable = false;

  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
    IdleAction = "suspend";
  };

  services.getty.autologinUser = "brian";
  environment.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      exec koreader
    fi
  '';

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
    };
  swapDevices = [ ];
  powerManagement.cpuFreqGovernor = "conservative"; # ondemand

  services.journald.extraConfig = "Storage=volatile";


  time.timeZone = "Europe/Amsterdam";

  services.openssh.enable = true;
  services.openssh.startWhenNeeded = true;
  services.openssh.settings.PermitRootLogin = "yes";

  networking.firewall.enable = false;
  networking.wireless.iwd.enable = true;
  hardware.bluetooth.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire.enable = false;

  systemd.services.btattach = {
    before = [ "bluetooth.service" ];
    after = [ "dev-ttymxc1.device" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bluez}/bin/btattach -B /dev/ttymxc1 -P h4 -S 1500000";
    };
  };

  environment.systemPackages = [
    pkgs.tmux
    pkgs.htop
    pkgs.koreader
  ];

  users.users.root.password = "nixos";
  users.users.david = {
    isNormalUser = true;
    password = "nixos";
    extraGroups = [ "wheel" "video" "input" ];

  };

  system.stateVersion = "21.11";
}
