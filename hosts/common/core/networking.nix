# Base networking configuration

{ lib, ... }:

let
  secrets = import ../../../secrets/network.nix;
  ips = secrets.lanIPs;
in
{
  networking.networkmanager.enable = lib.mkDefault true;

  # Local host resolution (DHCP IPs may change — update as needed)
  networking.extraHosts = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: ip: "${ip} ${name}") ips);
}
