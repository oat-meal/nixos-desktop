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
  fileSystems."/boot" = { device = "/dev/disk/by-uuid/6F55-0E9E"; fsType = "vfat"; options = [ "fmask=0077" "dmask=0077" ]; };

  swapDevices = [{ device = "/dev/zvol/rpool/swap"; }];
  boot.resumeDevice = "/dev/zvol/rpool/swap";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Required for ZFS
  networking.hostId = "aee09187";

  # LUKS2 encrypted root
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/198c5bd9-a718-4828-b7ce-c4124b02aa7c";
  };
}
