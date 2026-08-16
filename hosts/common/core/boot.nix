# Bootloader configuration
# UEFI + systemd-boot (default, can be overridden for servers)

{ lib, ... }:

{
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Bound the entries written to the ESP. nix.gc keeps 30 days of generations, which
  # is unbounded in ESP terms: each entry costs ~45MB (kernel + initrd) against a
  # 512MB partition, so ~11 fit. server-nixos was already at 54% with 6 entries, and a
  # single day of iteration can add five. A full ESP fails `nixos-rebuild` at the
  # bootloader step — on the headless host that means a console trip. 10 generations
  # is still a deep rollback history.
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;
}
