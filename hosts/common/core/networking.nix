# Base networking configuration

{ lib, ... }:

let
  secrets = import ../../../secrets/network.nix;
  ips = secrets.wireguard.meshIPs;
in
{
  networking.networkmanager.enable = lib.mkDefault true;

  # Host resolution via WireGuard mesh IPs (SSH is wg0-only)
  networking.extraHosts = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: ip: "${ip} ${name}") ips);
}
