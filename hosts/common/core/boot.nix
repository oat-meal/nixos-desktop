# Bootloader configuration
# UEFI + systemd-boot (default, can be overridden for servers)

{ lib, ... }:

{
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
