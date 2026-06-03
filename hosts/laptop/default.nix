# Framework 13 laptop configuration
# AMD Ryzen, Niri compositor, power management optimized

{ config, pkgs, lib, ... }:

{
  imports = [
    # Security
    ../common/optional/security/luks.nix
    ../common/optional/security/hardening.nix

    ./hardware-configuration.nix

    # Core (required)
    ../common/core

    # Desktop environment
    ../common/optional/desktop/niri
    ../common/optional/desktop/audio.nix
    ../common/optional/desktop/fonts.nix
    ../common/optional/desktop/apps.nix

    # Gaming
    ../common/optional/gaming

    # Hardware
    ../common/optional/hardware/amd.nix
    ../common/optional/hardware/bluetooth.nix
    ../common/optional/hardware/framework.nix

    # Networking
    ../common/optional/networking/firewall.nix
    ../common/optional/networking/nordvpn.nix
    ../common/optional/networking/syncthing.nix
    ../common/optional/networking/wifi.nix
    ../common/optional/networking/wireguard.nix

    # Power
    ../common/optional/power/portable.nix
    ../common/optional/power/hibernate.nix
  ];

  ################################
  ## Host identity
  ################################
  networking.hostName = "laptop-nixos";
  system.stateVersion = "25.05";

  ################################
  ## Kernel
  ################################
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_12;
  boot.consoleLogLevel = 1;

  # Laptop-specific kernel params
  boot.kernelParams = lib.mkAfter [
    "amd_pstate.shared_mem=1"
    "amdgpu.abmlevel=0"  # Disable adaptive backlight to prevent GPU idle lockups
  ];

  ################################
  ## GameMode override (laptop)
  ################################
  # 8-core laptop CPU: reserve 4 cores for system, pin games to 4
  programs.gamemode.settings.cpu.core_count = lib.mkForce 4;
  programs.gamemode.settings.gpu.gpu_device = lib.mkForce 1;  # GPU is card1 on this laptop

  ################################
  ## WiFi power saving (laptop)
  ################################
  networking.networkmanager.wifi.powersave = true;

  ################################
  ## SSH — LAN only
  ################################
  services.openssh = {
    enable = true;
    openFirewall = false;  # SSH restricted to wg0 below
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

  # Only allow SSH over WireGuard mesh
  networking.firewall.interfaces."wg0".allowedTCPPorts = [ 22 ];

  # Scoped passwordless sudo for management commands
  security.sudo.extraRules = [{
    users = [ "oat" ];
    commands = [
      { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/nix*"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/git"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/zfs"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/zpool"; options = [ "NOPASSWD" ]; }
    ];
  }];

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment.enable = true;
  };

  users.users.oat.openssh.authorizedKeys.keys = let
    secrets = import ../../secrets/network.nix;
  in [ secrets.sshKeys.workstation-nixos ];

  ################################
  ## ZFS maintenance
  ################################
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 4;
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 12;
  };

  ################################
  ## User groups
  ################################
  users.users.oat.extraGroups = lib.mkAfter [ "audio" "video" "input" "gamemode" ];
}
