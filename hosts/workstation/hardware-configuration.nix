{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = { device = "rpool/ROOT/nixos"; fsType = "zfs"; };
  fileSystems."/home" = { device = "rpool/home"; fsType = "zfs"; };
  fileSystems."/nix" = { device = "rpool/nix"; fsType = "zfs"; };
  fileSystems."/var/log" = { device = "rpool/log"; fsType = "zfs"; };
  fileSystems."/boot" = { device = "/dev/disk/by-uuid/7B4C-1833"; fsType = "vfat"; options = [ "fmask=0077" "dmask=0077" ]; };

  swapDevices = [{ device = "/dev/zvol/rpool/swap"; }];
  boot.resumeDevice = "/dev/zvol/rpool/swap";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Required for ZFS
  networking.hostId = "0f0a372c";

  # LUKS2 encrypted root
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/a54097ae-1450-424b-babc-a9711ba8c3a6";
  };

  # LUKS2 encrypted storage drives (unlocked via keyfile after cryptroot)
  boot.initrd.secrets."/etc/secrets/storage.key" = "/etc/secrets/storage.key";
  boot.initrd.luks.devices."cryptstorage1" = {
    device = "/dev/disk/by-uuid/73ce407c-06bd-413f-b8d2-f817e4e2380d";
    keyFile = "/etc/secrets/storage.key";
  };
  boot.initrd.luks.devices."cryptstorage2" = {
    device = "/dev/disk/by-uuid/ccf8ea84-236d-45d0-a8ff-88fc21abb3e9";
    keyFile = "/etc/secrets/storage.key";
  };

  # Auto-import storage ZFS pool (NOT rpool — it's imported by initrd)
  boot.zfs.extraPools = [ "storage" ];
}
