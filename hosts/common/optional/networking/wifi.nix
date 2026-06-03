# WiFi configuration
# Power saving and regulatory database

{ lib, pkgs, ... }:

{
  networking.networkmanager.wifi.powersave = lib.mkDefault false;

  hardware.wirelessRegulatoryDatabase = true;

  hardware.firmware = with pkgs; [
    wireless-regdb
  ];

  environment.systemPackages = with pkgs; [
    iw
    # wireguard-tools provided by nordvpn module
  ];
}
