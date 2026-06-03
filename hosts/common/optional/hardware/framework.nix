# Framework laptop specific configuration
# Fingerprint, backlight, and Framework tools

{ pkgs, ... }:

{
  # Framework laptop kernel module (fan control, etc.)
  boot.extraModulePackages = with pkgs.linuxPackages_6_12; [ framework-laptop-kmod ];
  boot.kernelModules = [ "framework_laptop" ];

  # Fingerprint reader
  services.fprintd.enable = true;

  # Backlight control
  programs.light.enable = true;

  # Framework laptop tools
  environment.systemPackages = with pkgs; [
    framework-tool
  ];

  # WiFi firmware and regulatory database provided by wifi.nix
}
