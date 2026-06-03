# DisplayLink USB display support
# For USB monitors like Elgato Prompter

{ config, pkgs, ... }:

{
  # Required even on Wayland - DisplayLink DRM/KMS output depends on the modesetting DDX
  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];

  # DisplayLink Manager service
  systemd.services.dlm.wantedBy = [ "multi-user.target" ];

  # EVDI kernel module
  boot.extraModulePackages = with config.boot.kernelPackages; [
    evdi
  ];

  boot.kernelModules = [ "evdi" ];

  environment.systemPackages = with pkgs; [
    displaylink
  ];
}
