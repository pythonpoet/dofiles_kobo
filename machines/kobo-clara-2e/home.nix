{ config, pkgs, lib, ... }:

{
  manual.manpages.enable = false;

  home.sessionVariables.EDITOR = "mg";

  programs.git = {
    enable = true;
    settings.user = {
      name = "David Wild"
      email = "32130052+pythonpoet@users.noreply.github.com";
    };
  };

  home.packages = [
    pkgs.mg
    pkgs.brightnessctl
  ];

  home.username = "david";
  home.homeDirectory = "/home/david";
  home.stateVersion = "26.05";
}
