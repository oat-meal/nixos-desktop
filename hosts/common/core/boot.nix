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

  # All three hosts are ZFS-root, so this applies fleet-wide.
  #
  # Pinned to the CURRENT default rather than changed. 26.05 warns that this flips to
  # false in 26.11; setting it explicitly keeps the 26.05 migration behaviour-neutral
  # and silences the warning. Moving to false is a SEPARATE decision — false is the
  # safer value (it refuses to import a pool another system may still own), and the
  # single-host-owns-its-rpool assumption should be confirmed per host before flipping.
  boot.zfs.forceImportRoot = lib.mkDefault true;
}
