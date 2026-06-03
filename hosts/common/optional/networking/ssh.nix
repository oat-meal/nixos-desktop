# SSH server — WireGuard mesh only
# Hardened sshd with fail2ban, restricted to wg0 interface

{ lib, ... }:

let
  secrets = import ../../../../secrets/network.nix;
in
{
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      AllowTcpForwarding = false;
    };
  };

  # SSH only over WireGuard mesh
  networking.firewall.interfaces."wg0".allowedTCPPorts = [ 22 ];

  # Authorize all lab host keys
  users.users.oat.openssh.authorizedKeys.keys = lib.attrValues secrets.sshKeys;

  # Rate-limit SSH brute force
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment.enable = true;
  };
}
