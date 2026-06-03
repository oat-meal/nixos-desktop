# Bluetooth configuration

{ ... }:

{
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  boot.kernelModules = [ "hidp" ];
}
