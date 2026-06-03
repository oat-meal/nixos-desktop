# VPS Relay Configuration
# Cloud-based relay for accessing home network services
#
# Purpose:
# - WireGuard VPN endpoint for home network access
# - Reverse proxy for selected services
# - Minimal footprint, security-focused

{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # No hardware-configuration.nix - VPS uses generated config
    ../common/core
    ../common/optional/networking/wireguard.nix
  ];

  # Host identity
  networking.hostName = "relay-nixos";
  system.stateVersion = "25.05";

  # Minimal user config for VPS
  users.users.oat.extraGroups = [ "wheel" ];

  # VPS-specific: use GRUB instead of systemd-boot
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";  # Typical VPS disk
  };

  # Firewall - strict by default
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH only
    allowedUDPPorts = [ 51820 ];  # WireGuard
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
