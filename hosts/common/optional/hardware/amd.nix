# AMD CPU and GPU configuration
# Microcode, drivers, and optimizations

{ config, lib, pkgs, ... }:

{
  # AMD CPU
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Kernel params for AMD
  boot.kernelParams = [
    "amd_pstate=active"
  ];

  # Firmware
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [
    linux-firmware
  ];
}
