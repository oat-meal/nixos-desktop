# LUKS2 + FIDO2 disk encryption support
# Enables systemd in initrd for fido2-device=auto unlock
# Import this on hosts with LUKS2 encrypted disks

{ config, pkgs, lib, ... }:

{
  # systemd initrd required for FIDO2 LUKS unlock
  boot.initrd.systemd.enable = true;

  # Ensure fido2 support is available in initrd
  boot.initrd.availableKernelModules = [
    "usbhid"      # USB HID for YubiKey
    "hid_generic"
  ];

  # Longer timeout for YubiKey tap during boot (default 90s is too short
  # if multiple LUKS devices need sequential unlock)
  boot.initrd.systemd.settings.Manager.DefaultTimeoutStartSec = "120s";

  # Note: boot.zfs.extraPools is set per-host in hardware-configuration.nix
  # (injected by the installer based on which pools were created)
}
