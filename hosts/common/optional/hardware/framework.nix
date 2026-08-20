# Framework laptop specific configuration
# Fingerprint, backlight, and Framework tools

{ pkgs, ... }:

{
  # Framework laptop kernel module (fan control, etc.)
  boot.extraModulePackages = with pkgs.linuxPackages_6_12; [ framework-laptop-kmod ];
  boot.kernelModules = [ "framework_laptop" ];

  # Fingerprint reader
  services.fprintd.enable = true;

  # Backlight control: brightnessctl, from desktop/base.nix.
  # programs.light was removed in 26.05 (unmaintained upstream). It was already
  # redundant here — nothing in this repo invoked `light`, and base.nix has
  # shipped brightnessctl all along, which is what the Mango keybinds use.

  # Framework laptop tools
  environment.systemPackages = with pkgs; [
    framework-tool
  ];

  # WiFi firmware and regulatory database provided by wifi.nix
}
