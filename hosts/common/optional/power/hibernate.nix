# Hibernate support (filesystem-agnostic)
# Policy only — no device paths or UUIDs here.
# swapDevices and boot.resumeDevice belong in hardware-configuration.nix
# (generated per-host by the installer based on actual disk layout)

{ lib, ... }:

{
  # systemd initrd required for clean hibernate/resume
  boot.initrd.systemd.enable = lib.mkDefault true;
}
